#!/bin/sh

source /etc/split-gateway/config

if ! grep -Fxq "101 split_gateway" /etc/iproute2/rt_tables; then
    echo "101 split_gateway" >> /etc/iproute2/rt_tables
fi
ip route add default table split_gateway via ${EXTERNAL_GATEWAY}
ip rule add fwmark 1 table split_gateway

exit 0
