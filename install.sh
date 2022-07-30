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

cp ./init-split-gateway.sh /etc/split-gateway/init-split-gateway.sh
chmod +x /etc/split-gateway/init-split-gateway.sh

cp ./rebuild-split-gateway.sh /etc/split-gateway/rebuild-split-gateway.sh
chmod +x /etc/split-gateway/rebuild-split-gateway.sh

cp ./init-split-gateway.service /etc/systemd/system/init-split-gateway.service

cp ./rebuild-split-gateway.path /etc/systemd/system/rebuild-split-gateway.path
cp ./rebuild-split-gateway.service /etc/systemd/system/rebuild-split-gateway.service

systemctl enable init-split-gateway.service
systemctl enable rebuild-split-gateway.path
systemctl enable rebuild-split-gateway.service

echo "Review /etc/split-gateway/config, if everything is fine,"
echo "start with:"
echo "sudo systemctl start init-split-gateway.service"

exit 0
