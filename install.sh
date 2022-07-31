#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

mkdir -p /etc/split-gateway/
cp ./config /etc/split-gateway/config

if [[ -z "${EXTERNAL_INTERFACE}" ]]; then 
    EXTERNAL_INTERFACE=$(ip route | tail -2 | head -1 | grep -oP '(?<=dev )eth[[:digit:]]{1,3}\.*[[:digit:]]{0,5}')
    echo "External interface not set, guessed interface: ${EXTERNAL_INTERFACE}"
fi
echo "EXTERNAL_INTERFACE='${EXTERNAL_INTERFACE}'" >> /etc/split-gateway/config

if [[ -z "${EXTERNAL_GATEWAY}" ]]; then 
    EXTERNAL_GATEWAY=$(ip route | grep ${EXTERNAL_INTERFACE} | cut -d' ' -f1 | cut -d'/' -f1 | sed 's/.$/1/')
    echo "External gateway not set, guessed gateway: ${EXTERNAL_GATEWAY}"
fi
echo "EXTERNAL_GATEWAY='${EXTERNAL_GATEWAY}'" >> /etc/split-gateway/config

if [[ -z "${NETWORK}" ]]; then 
    NETWORK=$(ip route | grep ${EXTERNAL_INTERFACE} | cut -d' ' -f1)
    echo "Network not set, guessed network: ${NETWORK}"
fi
echo "NETWORK='${NETWORK}'" >> /etc/split-gateway/config

cp ./split-gateway.sh /usr/bin/split-gateway
chmod +x /usr/bin/split-gateway

cp ./split-gateway.service /etc/systemd/system/split-gateway.service

cp ./watcher-split-gateway.path /etc/systemd/system/watcher-split-gateway.path
cp ./watcher-split-gateway.service /etc/systemd/system/watcher-split-gateway.service

systemctl enable split-gateway.service
systemctl enable watcher-split-gateway.service
systemctl enable watcher-split-gateway.path

echo "Review /etc/split-gateway/config, if everything is fine,"
echo "start with:"
echo "sudo systemctl start split-gateway watcher-split-gateway.{path,service}"
exit 0
