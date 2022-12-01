#!/bin/bash
# Developed by Antal Klemencsics, 2022 December

# --- VARIABLES ---
desiredSiteName="cmk"
desiredDataSourcePath="/tmp/checkmk/data"
desiredHostPort=5000


# --- MAIN ---
tput reset


# 1. Information gathering
echo -e '\n\nINFORMATION GATHERING'
printf '%.s─' $(seq 1 $(tput cols))


# 1.1 System architecture
echo -e "\n1. System architecture ...\n"

systemArchitecture="$(uname -m)"
availableSystemArchitectures=("arm64" "armhf")
availableSystemArchitecturesCount=${#availableSystemArchitectures[@]}

if [[ $systemArchitecture == 'aarch64' ]] || [[ $systemArchitecture == 'arm64' ]] ; then
    echo -e "- Auto-detected the system architecture:\narm64"
    desiredSystemArchitecture="arm64"
elif [[ $systemArchitecture == 'armv7l' ]] || [[ $systemArchitecture == 'armhf' ]]; then
    echo -e "- Auto-detected the system architecture:\narm64"
    desiredSystemArchitecture="armhf"
else
    echo -e "- Could not auto-detect the system architecture. You can choose from the following options:\n"
    for i in ${!availableSystemArchitectures[@]}; do
        echo -e "$i. \t ${availableSystemArchitectures[$i]}"
    done

    echo -e "- Please tpye in the desired system architecture's sequence number (0..$(($availableSystemArchitecturesCount - 1))):" ; read seqNumber
    if [[ $seqNumber == [[:digit:]]* ]] && (($seqNumber >= 0)) && (($seqNumber < $availableSystemArchitecturesCount)); then
        desiredSystemArchitecture=${availableSystemArchitectures[$seqNumber]}
    else
        echo -e "\n\nFATAL: Unavailable system architecture sequence number!" && exit 1
    fi
fi


# 1.2 CMK version
echo -e "\n2. Checkmk version ...\n"

package_download_urls=( $(curl --silent https://api.github.com/repos/chrisss404/check-mk-arm/releases | grep 'browser_download_url' | awk -F'": "' '{print $2}' | awk -F'"' '{print $1}' | grep "bullseye_$desiredSystemArchitecture") )
availablePackageCount=${#package_download_urls[@]}

if (( $availablePackageCount > 0 )); then
    echo "- Listing the available checkmk versions:"
else 
    echo -e "\n\nFATAL: Couldn't find appropriate packages (github API rate limit might have been exceed, try again later)!" && exit 1
fi

package_versions=()
for i in ${!package_download_urls[@]}; do
    package_versions[$i]=$(echo "$(echo ${package_download_urls[$i]} | awk 'BEGIN { FS = "/" } ; {print $(NF-1)}')")
    echo -e "$i. \t ${package_versions[$i]}\t${package_download_urls[$i]}"
done

echo -e "\n- Type in the desired checkmk versions's sequence number (0..$(($availablePackageCount - 1))):" ; read chosenPackageNr
if [[ $chosenPackageNr == [[:digit:]]* ]] && (($chosenPackageNr >= 0)) && (($chosenPackageNr < $availablePackageCount)); then
    desiredVersion=${package_versions[$chosenPackageNr]}
else
    echo -e "\n\nFATAL: Unavailable version sequence number!" && exit 1
fi

packageName="check-mk-raw-${desiredVersion}_0.bullseye_${desiredSystemArchitecture}.deb"


# 1.3 Checkmk site name
echo -e "\n3. Checkmk site name ...\n"
echo -e "-Define a custom checkmk site name, or press ENTER for the default setting ('$desiredSiteName'):" ; read response
if [[ ! $response == "" ]]; then desiredSiteName=$response; fi

imageTag="checkmk-$desiredSiteName:$desiredVersion"


# 1.4 Checkmk data source path
echo -e "\n4. Checkmk data source path ...\n"
echo "- Define a custom data source path, or press ENTER for the default setting ('$desiredDataSourcePath'):" ; read response
if [[ $response == "" ]]; then 
    mkdir -p $desiredDataSourcePath || ( echo -e "\n\nFATAL: Failed to create/access the default data source path !" && exit 1 )
else
    mkdir -p $response || ( echo -e "\n\nFATAL: Failed to create/access the custom data source path '$response' !" && exit 1 )
    desiredDataSourcePath=$response
fi


# 1.5 Checkmk host port
echo -e "\n5. Checkmk host port ...\n"
echo "- Define a custom host port, or press ENTER for the default setting ($desiredHostPort):" ; read response
if [[ ! $response == "" ]]; then desiredHostPort=$response; fi
if [[ ! $desiredHostPort == [[:digit:]]* ]]; then echo -e "\n\nFATAL: The port number '$desiredHostPort' is incorrect." && exit 1; fi
# TODO: also validate above that the chosen port is free to use (= NOT occupied already)


# 1.6 Cmkadmin user password
echo -e "\n6. Cmkadmin user password ...\n"
echo -e "-Type in the desired password for the 'cmkadmin' user on the '$desiredSiteName' site:" ; read desiredPassword


# 2. Setup
echo -e '\n\nSETUP'
printf '%.s─' $(seq 1 $(tput cols))


# 2.1 Detecting / downloading the desired package
echo -e "\n1. Detecting/downloading the '$packageName' package ...\n"

if [[ -f $packageName ]]; then
    echo '- The desired package is detected locally.' #TODO: add redownload option y/n
else 
    echo '- Downloading the package:'
    curl -LO ${package_download_urls[$chosenPackageNr]}
    if [[ ! -f $packageName ]]; then echo -e "\n\nFATAL: Failed to download the package." && exit 1; fi
fi


# 2.2 Building the docker image
echo -e "\n2. Building the docker image ..."

if [ $(docker images -q $imageTag) ]; then
    echo "- The image is already built." #TODO: add rebuild option y/n
else
    docker build -t $imageTag --build-arg CMK_VERSION=${desiredVersion} --build-arg CMK_SITE_ID=${desiredSiteName} --build-arg PACKAGE_NAME=${packageName} . || ( echo -e "\n\nFATAL: Failed to build the docker image." && exit 1 )
fi


# 2.3 Updating the docker-compose.yml
echo -e "\n3. Updating the docker-compose.yml via the .env file..."
echo -e "CONTAINER_NAME = 'checkmk-$desiredSiteName'\nIMAGE_NAME = '$imageTag'\nDATA_SOURCE_PATH = '$desiredDataSourcePath'\nHOST_PORT = $desiredHostPort" > .env


# 2.4 Starting the container
echo -e "\n4. Starting the container ..."
docker compose up -d || ( echo -e "\n\nFATAL: Failed to compose the container !" && exit 1 )
containerID=$(docker ps | grep checkmk-$desiredSiteName:$desiredVersion | awk '{print $1}')

echo "- Waiting on the container to boot:"
lastLog="$(docker logs -n 1 $containerID)"
while [[ $lastLog != "### CONTAINER STARTED" ]]; do
    echo "waiting ..."
    sleep 10
    lastLog="$(docker logs -n 1 $containerID)"
done


# 2.5 Changing the default password of the cmkadmin user
echo -e "\n5. Changing the default password for 'cmkadmin' user ..."
docker exec -t "$containerID" /bin/bash -c "htpasswd -b /omd/sites/$desiredSiteName/etc/htpasswd cmkadmin $desiredPassword"


# 3. FINISHED
echo -e '\n\nFINISHED'
printf '%.s─' $(seq 1 $(tput cols))

if [ "$(ipconfig getifaddr en0)" ]; then 
    ip="$(ipconfig getifaddr en0)"
elif [ "$(hostname -I | awk -F' ' '{print $1}')" ]; then
    ip="$(hostname -I | awk -F' ' '{print $1}')"
else
    ip="yourHostIP"
fi

echo -e "You can now access your checkmk site at:"
echo -e "\nURL:\thttp://$ip:$desiredHostPort/$desiredSiteName/check_mk/"
echo -e "USER:\tcmkadmin"
echo -e "PW:\t$desiredPassword"

# ----
# TODO: ask if we want to set up multiple sites (= multiple containers on the same network where every container is one site)
# assembling the docker-compose.yml
# gather every local checkmk image then add the as new services (one service per site - if there's more than one version for the same site, ask user to delete the older ones, then continue with the last modified for the site)
# ask for data bind mount filepath, default should be /etc/checkmk/data (create if not existent) -- then fill this in the compose file
# I might need to define a custom host path for each container /data, as checkmk seems to have an apache issue if multiple sites are under the same directory (like now with /tmp/checkmk/data)