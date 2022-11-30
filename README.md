# checkmk-arm-docker

**This repository will help you quickly build a docker image from a custom Debian ARM Checkmk package.**

Please note that currently **only the checkmk version 2.1.0p16 on arm64/armhf system architecture is supported** by this project out-of-the-box.

> **Note**
>
> A **helper script** is being developed so that the project could cover more specific needs (more cmk versions, more supported system architectures). With the script, the installation and container handling will also be simplified and multi-site support (multiple container setup) will be added.

## Build a docker image

1. Clone this repository, then change the working directory to the downloaded local git repo
2. Download the right ARM checkmk package
    - if you run `uname -m` and the result is *aarch64*, you need to download the **arm64** version:
        - `curl -LO $(curl -s https://api.github.com/repos/chrisss404/check-mk-arm/releases/tags/2.1.0p16 | grep browser_download_url | cut -d '"' -f 4 | grep bullseye_arm64.deb)`
    - if you run `uname -m` and the result is *armv7l*, you need to download the **armhf** version:
        - `curl -LO $(curl -s https://api.github.com/repos/chrisss404/check-mk-arm/releases/tags/2.1.0p16 | grep browser_download_url | cut -d '"' -f 4 | grep bullseye_armhf.deb)`
3. Build your docker image: `docker build -t 'checkmk-cmk:2.1.0p16' .`

## Start the container

1. Create a folder to store the checkmk sites' data : `mkdir /tmp/checkmk/ && mkdir /tmp/checkmk/data`
    - You can edit this location as desired, but in this case, don't forget to update the `docker-compose.yml` file either: the first bind volume's host path has to be adjusted accordingly.
2. Start up your container based on your newly built image: `docker compose up -d`
3. After a few seconds, you'll be able to access the checkmk web UI via <http://hostIP:5000/cmk/check_mk/> (adjust the hostIP).
    - If you don't know the hostIP, running `hostname -I | awk -F' ' '{print $1}'` on the host will tell you.
    - The default username is '*cmkadmin*', the default password is '*adminadmin*'.
4. **Once you've logged in, change the cmkadmin user's password ASAP!**
    - You can change the user's password under setup/users, and look for the *cmkadmin* user. Don't use the '*Change password at next login or access*' setting!

## Stop the container

- To **stop** the running container, simply change directory to the git folder where you've cloned the project, then run `docker compose down` .

## References

The custom Debian ARM Checkmk binary is downloaded from [chrisss404/check-mk-arm](https://github.com/chrisss404/check-mk-arm) GitHub releases.

The docker files were inspired by the [original checkmk repo](https://github.com/tribe29/checkmk).
