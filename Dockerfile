# This file was created based on https://raw.githubusercontent.com/tribe29/checkmk/master/docker_image/Dockerfile

# Building the base image (parameterised by --build-arg from the helper script based on the correct debian version)
ARG IMAGE_CMK_BASE
FROM ${IMAGE_CMK_BASE}

# Set up build-time variables for checkmk (these default values will be overwritten by the helper script witg --build-args
# be careful, as these values will be visible in the docker history!
ARG CMK_VERSION="2.1.0p16"
ARG CMK_EDITION="raw"
ARG CMK_SITE_ID="cmk"
ARG CMK_PASSWORD="adminadmin"
ARG PACKAGE_NAME="check-mk-raw-2.1.0p16*arm64.deb"
ARG CMK_LIVESTATUS_TCP=""
ARG MAIL_RELAY_HOST=""

# Set up run-time variables for checkmk (these are NOT visible in the docker history)
ENV CMK_SITE_ID ${CMK_SITE_ID}
ENV CMK_PASSWORD ${CMK_PASSWORD}
ENV PACKAGE_NAME ${PACKAGE_NAME}
ENV CMK_LIVESTATUS_TCP ${CMK_LIVESTATUS_TCP}
ENV MAIL_RELAY_HOST ${MAIL_RELAY_HOST}
ENV CMK_CONTAINERIZED="TRUE"

# Updating Debian
RUN apt-get update && apt-get upgrade -y

# Copy the ARM64 compatible CheckMK package file to the container
COPY ${PACKAGE_NAME} /tmp/

# Install the copied checkmk package and its dependencies
RUN dpkg -i /tmp/check-mk-raw-*.deb ; apt-get install -f -y

# Cleanup the unnecessary files
RUN apt-get clean && rm -rf /tmp/*

# Open the neccessary ports
# 5000 - Serves the Checkmk GUI
# 6557 - Serves Livestatus (if enabled via "omd config")
EXPOSE 5000 6557

# Check if the installation was successful
HEALTHCHECK --interval=1m --timeout=5s \
    CMD omd status || exit 1

# Copy and setup of the entrypoint script
COPY docker-entrypoint.sh /
RUN ["chmod", "+x", "/docker-entrypoint.sh"]

# Start the entrypoint script and hand over to the CMD
ENTRYPOINT ["/docker-entrypoint.sh"]