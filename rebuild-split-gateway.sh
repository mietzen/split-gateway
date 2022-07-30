#!/bin/bash

# Get vars
source /etc/split-gateway/config

# Get opened ports from IPTables
OPENED_PORTS_IPT=$(mktemp -p /dev/shm/)
IPT_PORTS=( $(iptables-save | grep Split-Gateway | grep -oP '(?<=--sport )[0-9]{1,5}') )
IPT_PROTO=( $(iptables-save | grep Split-Gateway | grep -oP '(?<=-p )(tcp|udp)') )
for i in "${!IPT_PORTS[@]}"; do 
    echo "${IPT_PORTS[$i]}/${IPT_PROTO[$i]}" >> ${OPENED_PORTS_IPT}
done
OPENED_PORTS_OLD=$(cat "${OPENED_PORTS_IPT}" 2>/dev/null || echo '')
rm -rf ${OPENED_PORTS_IPT}

# Get opened ports from UFW
if [ $REGEX_IFACE_EXPLICIT = false ]; then
    REGEX="^[[:digit:]]{1,5}/(tcp|udp)( on ${EXTERNAL_INTERFACE} [[:space:]]* ALLOW | [[:space:]]* ALLOW)[[:space:]]* Anywhere [[:space:]]*$"
else 
    REGEX="^[[:digit:]]{1,5}/(tcp|udp) on ${EXTERNAL_INTERFACE} [[:space:]]* ALLOW [[:space:]]* Anywhere [[:space:]]*$" 
fi
OPENED_PORTS_NEW=$(ufw status | egrep "${REGEX}" | cut -d' ' -f1)

function rebuild_split_gateway {
    # Delete all 'Split-Gateway' rules
    for rule in $(iptables -t mangle -L --line-numbers | grep Split-Gateway | cut -d' ' -f1 | sort -r); do
        iptables -t mangle -D OUTPUT ${rule}
    done

    # Import all rules from UFW
    for line in ${OPENED_PORTS_NEW}; do
        IFS="/" read -r PORT PROTOCOL <<< ${line}
        iptables -t mangle -A OUTPUT ! -d ${NETWORK} -p ${PROTOCOL} --sport ${PORT} -j MARK --set-mark 1 -m comment --comment 'Split-Gateway'
    done
}

# Only run if something is changed
if [ "${OPENED_PORTS_NEW}" != "${OPENED_PORTS_OLD}" ]; then
    rebuild_split_gateway
fi

exit 0
