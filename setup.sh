#!/bin/bash
# Developed by Antal Klemencsics, 2022 December

# --- VARIABLES ---
availableVersions=( $(curl --silent https://api.github.com/repos/chrisss404/check-mk-arm/tags | grep 'name' | awk -F'": "' '{print $2}' | awk -F'"' '{print $1}') )
#TODO: filter for bullseye packages
availableVersionsCount=${#availableVersions[@]}
availableSystemArchitectures=("arm64" "armhf")
availableSystemArchitecturesCount=${#availableSystemArchitectures[@]}
systemArchitecture="$(uname -m)"

# Initialising with default values
desiredSiteName="cmk"
desiredDataSourcePath="/tmp/checkmk/data"
desiredHostPort=5000


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
if [[ $seqNumber == [[:digit:]]* ]] && (($seqNumber >= 0)) && (($seqNumber < $availableVersionsCount)); then
    desiredVersion=${availableVersions[$seqNumber]}
else
    echo -e "\n\n FATAL: Unavailable version sequence number!" && exit 1
fi

# 2. Detecting / requesting the desired system architecture

echo -e '\n\nSYSTEM ARCHITECTURE SETUP'
printf '%.s─' $(seq 1 $(tput cols))

if [[ $systemArchitecture == 'aarch64' ]] || [[ $systemArchitecture == 'arm64' ]] ; then
    echo -e "\nAuto-detected the system architecture:\narm64"
    desiredSystemArchitecture="arm64"
elif [[ $systemArchitecture == 'armv7l' ]] || [[ $systemArchitecture == 'armhf' ]]; then
    echo -e "\nAuto-detected the system architecture:\narm64"
    desiredSystemArchitecture="armhf"
else
    echo -e "\nCould not auto-detect the system architecture. You can choose from the following options:\n"
    for i in ${!availableSystemArchitectures[@]}; do
        echo -e "$i. \t ${availableSystemArchitectures[$i]}"
    done

    echo -e "\nPlease tpye in the desired system architecture's sequence number (0..$(($availableSystemArchitecturesCount - 1))):" ; read seqNumber
    if [[ $seqNumber == [[:digit:]]* ]] && (($seqNumber >= 0)) && (($seqNumber < $availableSystemArchitecturesCount)); then
        desiredSystemArchitecture=${availableSystemArchitectures[$seqNumber]}
    else
        echo -e "\n\nFATAL: Unavailable system architecture sequence number!" && exit 1
    fi
fi

# 3. Requesting the desired site name

echo -e '\n\nCHECKMK SITE SETUP'
printf '%.s─' $(seq 1 $(tput cols))

echo -e "\nDefine a custom checkmk site name, or press ENTER (default is '$desiredSiteName'):" ; read response
if [[ ! $response == "" ]]; then desiredSiteName=$response; fi

# 4. Setup orchestrating

echo -e '\n\nSETUP ORCHESTRATION'
printf '%.s─' $(seq 1 $(tput cols))

packageName="check-mk-raw-${desiredVersion}_0.bullseye_${desiredSystemArchitecture}.deb"
imageTag="checkmk-$desiredSiteName:$desiredVersion"

# 4.1 Detecting / downloading the desired package
echo -e "\n1. Detecting/downloading the '$packageName' package ..."

if [[ -f $packageName ]]; then
    echo '- The desired package is detected locally.' #TODO: add redownload option y/n
else 
    echo '- Downloading the package ...'
    curl -LO $(curl -s https://api.github.com/repos/chrisss404/check-mk-arm/releases/tags/$desiredVersion | grep browser_download_url | cut -d '"' -f 4 | grep bullseye_$desiredSystemArchitecture.deb)
    if [[ -f $packageName ]]; then echo '- Successfully downloaded the package.'; else echo -e "\n\nFATAL: Failed to download the package." && exit 1; fi
fi

# 4.2 Building the docker image
echo -e "\n2. Building the docker image ..."

if [ $(docker images -q $imageTag) ]; then
    echo "- The image is already built." #TODO: add rebuild option y/n
else
    docker build -t $imageTag --build-arg CMK_VERSION=${desiredVersion} --build-arg CMK_SITE_ID=${desiredSiteName} --build-arg PACKAGE_NAME=${packageName} .
fi

# 4.3 Updating the docker-compose.yml
echo -e "\n3. Updating the docker-compose.yml via the .env file..."

echo "- Define a custom data source path, or press ENTER (default is '$desiredDataSourcePath'):" ; read response
if [[ $response == "" ]]; then 
    mkdir -p $desiredDataSourcePath || ( echo -e "\n\n FATAL: Failed to create/access the default data source path !" && exit 1 )
else
    mkdir -p $response || ( echo -e "\n\n FATAL: Failed to create/access the custom data source path '$response' !" && exit 1 )
    desiredDataSourcePath=$response
fi

echo "- Define a custom host port, or press ENTER (default is $desiredHostPort):" ; read response
if [[ ! $response == "" ]]; then desiredHostPort=$response; fi
if [[ ! $desiredHostPort == [[:digit:]]* ]]; then echo -e "\n\n FATAL: The port number '$desiredHostPort' is incorrect." && exit 1; fi
# TODO: also validate above that the chosen port is free to use (= NOT occupied already)

echo -e "CONTAINER_NAME = 'checkmk-$desiredSiteName'\nIMAGE_NAME = '$imageTag'\nDATA_SOURCE_PATH = '$desiredDataSourcePath'\nHOST_PORT = $desiredHostPort" > .env

# 4.4 Starting the container
echo -e "\n4. Starting the container ..."
docker compose up -d || ( echo -e "\n\n FATAL: Failed to compose the container !" && exit 1 )

# 4.5 Changing the default password of the cmkadmin user
echo -e "\n5. Changing the default password of the 'cmkadmin' user on the '$desiredSiteName' site ..."
echo -e "-Type in the desired password:" ; read desiredPassword
containerID=$(docker ps | grep checkmk-$desiredSiteName:$desiredVersion | awk '{print $1}')
docker exec -t "$containerID" /bin/bash -c "htpasswd -b /omd/sites/$desiredSiteName/etc/htpasswd cmkadmin $desiredPassword"

# 5. INFO

echo -e '\n\nSUCCESS'
printf '%.s─' $(seq 1 $(tput cols))

if [ "$(ipconfig getifaddr en0)" ]; then 
    ip="$(ipconfig getifaddr en0)"
elif [ "$(hostname -I | awk -F' ' '{print $1}')" ]; then
    ip="$(hostname -I | awk -F' ' '{print $1}')"
else
    ip="yourHostIP"
fi

echo -e "Wait a minute or so until the cmk site loads up, then you'll be able to access your site at:"
echo -e "\nURL:\thttp://$ip:5000/$desiredSiteName/check_mk/"
echo -e "USER:\tcmkadmin"
echo -e "PW:\t$desiredPassword"

# ----
# TODO: ask if we want to set up multiple sites (= multiple containers on the same network where every container is one site)
# assembling the docker-compose.yml
# gather every local checkmk image then add the as new services (one service per site - if there's more than one version for the same site, ask user to delete the older ones, then continue with the last modified for the site)
# ask for data bind mount filepath, default should be /etc/checkmk/data (create if not existent) -- then fill this in the compose file