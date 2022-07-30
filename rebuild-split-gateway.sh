#!/bin/bash

# Get vars
source /etc/split-gateway/config

if [[ "$1" = "init" ]]; then
    OPENED_PORTS_OLD=''
else
    OPENED_PORTS_OLD=$(cat "${OPENED_PORTS_FILE}" > /dev/null 2>&1 || echo '')
fi

if [ $REGEX_IFACE_EXPLICIT = false ]; then
    REGEX="^[[:digit:]]{1,5}/(tcp|udp)( on ${EXTERNAL_INTERFACE} [[:space:]]* ALLOW | [[:space:]]* ALLOW)[[:space:]]* Anywhere [[:space:]]*$"
else 
    REGEX="^[[:digit:]]{1,5}/(tcp|udp) on ${EXTERNAL_INTERFACE} [[:space:]]* ALLOW [[:space:]]* Anywhere [[:space:]]*$" 
fi

OPENED_PORTS_NEW=$(ufw status | egrep "${REGEX}" | cut -d' ' -f1)

function rebuild_split_gateway {
    rm -rf ${OPENED_PORTS_FILE}

    # Delete all 'Split-Gateway' rules
    for rule in $(iptables -t mangle -L --line-numbers | grep Split-Gateway | cut -d' ' -f1 | sort -r); do
        iptables -t mangle -D OUTPUT ${rule}
    done

    # Import all rules from UFW
    for line in ${OPENED_PORTS_NEW}; do
        echo ${line} >> ${OPENED_PORTS_FILE}
        IFS="/" read -r PORT PROTOCOL <<< ${line}
        iptables -t mangle -A OUTPUT ! -d ${NETWORK} -p ${PROTOCOL} --sport ${PORT} -j MARK --set-mark 1 -m comment --comment 'Split-Gateway'
    done
}

if [ "${OPENED_PORTS_NEW}" != "${OPENED_PORTS_OLD}" ]; then
    rebuild_split_gateway
fi

exit 0
