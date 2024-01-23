# checkmk-arm-docker for debian

This repository will help you achieve the followings by following informative CLI prompts:

- quickly **find and download the proper Debian ARM Checkmk package**
- **automatically build a docker image from this package**
- quickly **customise and setup your cmk site**
- **start the newly built and customised cmk site in the background**

This repo's automated setup process enables you to simply set up a home monitoring solution (CheckMK RAW edition) on your Debian ARM device (such as a raspberry pi).

## Automated setup

This solution were successfully tested on both Raspberry Pi 4 and Apple Silicon MAC.

The project is not yet able to run multiple containers simultainiously (this feature will be added with the next major version), but it can build multiple images and run the selected one.

> **Note**
>
> It is highly recommended to use the  **setup script** for the setup process as it:
>
> - offers the entire release library of arm checkmk packages to be automatically downloaded (so you can precisely choose the desired version)
> - can automatically detect the system architecture
> - can automatically detect the correct debian version
> - can automatically build the docker image
> - enables you to set up a custom site name, data source path, host port number
> - enables you to easily change the default password of the 'cmkadmin' user during the installation
> - prints the essential information (URL, username, pw) for the created cmk site once the setup is done

### Steps

1. Clone this git repository, then change the working directory to the downloaded local git repo.
2. Make sure you have **curl** installed (if not, `apt-get install curl -y`).
3. Run `./setup.sh` from your terminal and follow the on-screen instructions.
4. DONE! You can now access your monitoring site on the URL provided by the setup script.

## Container management

The easiest way is to handle the containers with the Docker Desktop app. If you have a headless setup, follow the steps below.

- To **start** the container, simply change directory to the git folder where you've cloned the project, then run `docker compose up -d` .
  - Please note that during the automatic installation, the container will automatically be started in the background !
- To **stop** the running container, simply change directory to the git folder where you've cloned the project, then run `docker compose down` .
- To **stop && remove** the running container, simply run `docker rm -f <containerID>` (you can look up the containerID with `docker ps`).

## References

- The custom Debian ARM Checkmk binary is downloaded from [chrisss404/check-mk-arm](https://github.com/chrisss404/check-mk-arm) GitHub releases.
- The docker files were inspired by the [original checkmk repo](https://github.com/tribe29/checkmk).

---

## Manual setup (deprecated)

Please note that in the manual setup guide **only the checkmk version 2.1.0p16 on arm64/armhf system architecture is covered** as an example.

### Building a docker image manually

1. Clone this repository, then change the working directory to the downloaded local git repo
2. Download the right ARM checkmk package
    - if you run `uname -m` and the result is *aarch64* or *arm64*, you need to download the **arm64** version:
        - `curl -LO $(curl -s https://api.github.com/repos/chrisss404/check-mk-arm/releases/tags/2.1.0p16 | grep browser_download_url | cut -d '"' -f 4 | grep bullseye_arm64.deb)`
    - if you run `uname -m` and the result is *armv7l*, you need to download the **armhf** version:
        - `curl -LO $(curl -s https://api.github.com/repos/chrisss404/check-mk-arm/releases/tags/2.1.0p16 | grep browser_download_url | cut -d '"' -f 4 | grep bullseye_armhf.deb)`
3. Build your docker image: `docker build -t 'checkmk-cmk:2.1.0p16' .`

### Starting the container manually

1. Create a folder to store the checkmk sites' data : `mkdir -p /tmp/checkmk/data`
    - You can edit this location as desired, but in this case, don't forget to update the `docker-compose.yml` file either: the first bind volume's host path has to be adjusted accordingly.
2. Start up your container based on your newly built image: `docker compose up -d`
3. After a minute or so, you'll be able to access the checkmk web UI via <http://hostIP:5000/cmk/check_mk/> (adjust the hostIP).
    - The default username is '*cmkadmin*', the default password is '*adminadmin*'.
4. **Once you've logged in, change the cmkadmin user's password ASAP!**
    - You can change the user's password under setup/users, and look for the *cmkadmin* user. Don't use the '*Change password at next login or access*' setting!
    - **This step is crucial**, as the default password build-time variable's value can be inspected in the image or by running docker history!
