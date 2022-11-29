# This file was created based on https://raw.githubusercontent.com/tribe29/checkmk/master/docker_image/Dockerfile

FROM debian:bullseye-slim

# Setting the checkmk variables
# TODO: set up CMK_VERSION ARG and CMK_SITE_ID ENV based on user input via the helper.py
ARG CMK_VERSION="2.1.0p16"
ARG CMK_EDITION="raw"
ARG CMK_SITE_ID
ENV CMK_SITE_ID="cmk"
ARG CMK_LIVESTATUS_TCP
ENV CMK_LIVESTATUS_TCP=""
ARG CMK_PASSWORD
ENV CMK_PASSWORD="adminadmin"
ARG MAIL_RELAY_HOST
ENV MAIL_RELAY_HOST=""
ENV CMK_CONTAINERIZED="TRUE"

# Updating Debian
RUN apt-get update && apt-get upgrade -y

# Copy the ARM64 compatible Check-mk binary file to the container
# TODO: based on helper.py -> COPY check-mk-raw-<version>•<architecture>.deb /tmp/
COPY check-mk-raw-2.1.0p16•arm64.deb /tmp/

# Install checkmk and its dependencies
RUN dpkg -i /tmp/check-mk-raw-*.deb ; apt-get install -f -y

# Cleanup the unnecessary files
RUN apt-get clean && rm -rf /tmp/*

# Open the neccessary ports
EXPOSE 5000 6557

# Check if the installation was successful
HEALTHCHECK --interval=1m --timeout=5s CMD omd status || exit 1

# Copy and setup of the entrypoint script
COPY docker-entrypoint.sh /
RUN ["chmod", "+x", "/docker-entrypoint.sh"]

# Start the entrypoint script and hand over to the CMD
ENTRYPOINT ["/docker-entrypoint.sh"]