#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

systemctl stop split-gateway watcher-split-gateway.{path,service}

systemctl disable split-gateway.service
systemctl disable watcher-split-gateway.service
systemctl disable watcher-split-gateway.path

rm -rf /etc/split-gateway/
rm -rf /usr/bin/split-gateway
rm -rf /etc/systemd/system/split-gateway.service
rm -rf /etc/systemd/system/watcher-split-gateway.path
rm -rf /etc/systemd/system/watcher-split-gateway.service

exit 0
