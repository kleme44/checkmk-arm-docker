#!/bin/bash
# Developed by Antal Klemencsics, 2022 December

# --- VARIABLES ---
availableVersions=( $(curl --silent https://api.github.com/repos/chrisss404/check-mk-arm/tags | grep 'name' | awk -F'": "' '{print $2}' | awk -F'"' '{print $1}') )
availableVersionsCount=${#availableVersions[@]}
desiredVersion=""

availableSystemArchitectures=("arm64" "armhf")
availableSystemArchitecturesCount=${#availableSystemArchitectures[@]}
desiredSystemArchitecture=""

desiredSiteName=""
desiredPassword=""


# --- MAIN ---
tput reset

# 1. Requesting the desired cmk version

echo 'CMK VERSION SETUP'
printf '%.s─' $(seq 1 $(tput cols))

echo -e "The available ARM checkmk-raw versions:\n"
for i in ${!availableVersions[@]}; do
    echo -e "$i. \t ${availableVersions[$i]}"
done

echo -e "\nType in the desired versions's sequence number (0..$(($availableVersionsCount - 1))):" ; read seqNumber
if (($seqNumber >= 0)) && (($seqNumber < $availableVersionsCount)); then
    desiredVersion=${availableVersions[$seqNumber]}
else
    echo "Unavailable version sequence number!"
    exit 1
fi

# 2. Detecting / requesting the desired system architecture

echo -e '\n\nSYSTEM ARCHITECTURE SETUP'
printf '%.s─' $(seq 1 $(tput cols))

unameValue="$(uname -m)"

if [[ $unameValue == 'aarch64' ]] || [[ $unameValue == 'arm64' ]] ; then
    echo -e "\nAuto-detected the system architecture:\narm64"
    desiredSystemArchitecture="arm64"
elif [[ $unameValue == 'armv7l' ]] || [[ $unameValue == 'armhf' ]]; then
    echo -e "\nAuto-detected the system architecture:\narm64"
    desiredSystemArchitecture="armhf"
else
    echo -e "\nCould not auto-detect the system architecture. You can choose from the following options:\n"
    for i in ${!availableSystemArchitectures[@]}; do
        echo -e "$i. \t ${availableSystemArchitectures[$i]}"
    done

    echo -e "\nPlease tpye in the desired system architecture's sequence number (0..$(($availableSystemArchitecturesCount - 1))):" ; read seqNumber
    if (($seqNumber >= 0)) && (($seqNumber < $availableSystemArchitecturesCount)); then
        desiredSystemArchitecture=${availableSystemArchitectures[$seqNumber]}
    else
        echo "Unavailable system architecture sequence number!"
        exit 1
    fi
fi

# 3. Requesting the desired site name

echo -e '\n\nCHECKMK SITE SETUP'
printf '%.s─' $(seq 1 $(tput cols))

echo -e "\nType in the desired checkmk site NAME:" ; read desiredSiteName

# 4. Setup orchestrating

echo -e '\n\nSETUP ORCHESTRATION'
printf '%.s─' $(seq 1 $(tput cols))

packageName="check-mk-raw-${desiredVersion}_0.bullseye_${desiredSystemArchitecture}.deb"
imageTag="checkmk-$desiredSiteName:$desiredVersion"

# 4.1 Detecting / downloading the desired package
echo -e "\n1. Detecting / downloading the '$packageName' package:"

if [[ -f $packageName ]]; then
    echo '- The desired package is detected locally.' #TODO: add redownload option y/n
else 
    echo '- Downloading the package ...'
    curl -LO $(curl -s https://api.github.com/repos/chrisss404/check-mk-arm/releases/tags/$desiredVersion | grep browser_download_url | cut -d '"' -f 4 | grep bullseye_$desiredSystemArchitecture.deb)
    
    if [[ -f $packageName ]]; then
        echo '- Successfully downloaded the package.'
    else
        echo '- Failed to download the package.'
        exit 1
    fi
fi

# 4.2 Building the docker image
echo -e "\n2. Building the docker image ..."

if [ $(docker images -q $imageTag) ]; then
    echo "- The image is already built." #TODO: add rebuild option y/n
else
    docker build -t $imageTag --build-arg CMK_VERSION=${desiredVersion} --build-arg CMK_SITE_ID=${desiredSiteName} --build-arg PACKAGE_NAME=${packageName} .
fi

# 4.3 Updating the docker-compose.yml
echo -e "\n3. Updating the docker-compose.yml ..."

echo "- Define a custom data source path, or press ENTER (default is '/tmp/checkmk/data'):" ; read response
if [[ $response = "" ]]; then 
    mkdir -p "/tmp/checkmk/data"
    dataSourcePath="/tmp/checkmk/data"
else
    mkdir -p $response || echo "- Failed to create/access the custom data source path!" ; exit 1
    dataSourcePath=$response
fi

echo "- Define a custom available host port, or press ENTER (default is 5000):" ; read response
if [[ $response = "" ]]; then 
    hostPort=5000
else
    hostPort=$response
fi

echo -e "IMAGE_NAME = '$imageTag'\nDATA_SOURCE_PATH = '$dataSourcePath'\nHOST_PORT = $hostPort" > .env

# 4.4 Starting the container
echo -e "\n4. Starting the container ..."
docker compose up -d

# 4.5 Changing the default password of the cmkadmin user
echo -e "\nType in the desired PASSWORD for the '$desiredSiteName' site's cmkadmin user:" ; read desiredPassword
containerID=$(docker ps | grep checkmk-$desiredSiteName:$desiredVersion | awk '{print $1}')
docker exec -t $containerID /bin/bash -c "htpasswd -bc /omd/sites/$desiredSiteName/etc/htpasswd cmkadmin $desiredPassword"

# 5. INFO

echo -e '\n\nDONE'
printf '%.s─' $(seq 1 $(tput cols))

if [ "$(ipconfig getifaddr en0)" ]; then 
    ip="$(ipconfig getifaddr en0)"
elif [ "$(hostname -I | awk -F' ' '{print $1}')" ]; then
    ip="$(hostname -I | awk -F' ' '{print $1}')"
else
    ip="yourHostIP"
fi

echo -e "SUCCESS! Wait a minute or two until the cmk site loads up, then you'll be able to access your site at:"
echo -e "\nURL:\thttp://$ip:5000/$desiredSiteName/check_mk/"
echo -e "User:\tcmkadmin"
echo -e "Pw:\t$desiredPassword"

# ----
# TODO: ask if we want to set up multiple sites (= multiple containers on the same network where every container is one site)
# assembling the docker-compose.yml
# gather every local checkmk image then add the as new services (one service per site - if there's more than one version for the same site, ask user to delete the older ones, then continue with the last modified for the site)
# ask for data bind mount filepath, default should be /etc/checkmk/data (create if not existent) -- then fill this in the compose file