# checkmk-arm-docker

**This repository will help you quickly build a docker image from a custom Debian ARM Checkmk package.**

Please note that currently **only the checkmk version 2.1.0p16 on arm64/armhf system architecture is supported** by this project out-of-the-box.

> **Note**
> A *helper.py* script is being developed so that the project could cover more specific needs (more cmk versions, more supported system architectures). Thanks to the script, the installation and container handling will also be simplified.

## Build a docker image

1. Clone this repository, then change the working directory to the downloaded local git repo
2. Download the ARM checkmk package:
    - for **arm64** file system: `curl -LO https://github.com/chrisss404/check-mk-arm/releases/download/2.1.0p16/check-mk-raw-2.1.0p16_0.bullseye_arm64.deb`
    - for **armhf** file system: `curl -LO https://github.com/chrisss404/check-mk-arm/releases/download/2.1.0p16/check-mk-raw-2.1.0p16_0.bullseye_armhf.deb`
3. Build your docker image: `docker build -t 'checkmk-cmk:2.1.0p16' .`
4. Create a folder to store the checkmk sites' data : `mkdir /tmp/checkmk/data`
    - You can edit this location as desired, but in this case, don't forget to update the `docker-compose.yml` file either: the first bind volume's host path has to be adjusted accordingly.

## Start the container

1. Start up your container based on your newly built image: `docker compose up -d`
2. After a few seconds, you'll be able to access the checkmk web UI via <http://hostIP:5000/cmk/check_mk/> (adjust the hostIP).
    - If you don't know the hostIP, running `hostname -I | awk -F' ' '{print $1}'` on the host will tell you.
    - The default username is '*cmkadmin*', the default password is '*adminadmin*'.
3. **Once you've logged in, change the cmkadmin user's password ASAP!**

## Stop the container

- To **stop** the running container, simply change directory to the git folder where you've cloned the project, then run `docker compose down` .

## References

The custom Debian ARM Checkmk binary is downloaded from [chrisss404/check-mk-arm](https://github.com/chrisss404/check-mk-arm) GitHub releases.

The docker files were inspired by the [original checkmk repo](https://github.com/tribe29/checkmk).
