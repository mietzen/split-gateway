#!/bin/bash

source /etc/split-gateway/config

function init {
    if ! grep -Fxq "101 split_gateway" /etc/iproute2/rt_tables; then
        echo "101 split_gateway" >> /etc/iproute2/rt_tables
    fi
    ip route add default table split_gateway via ${EXTERNAL_GATEWAY}
    ip rule add fwmark 1 table split_gateway
}

function reload {
    # Get opened ports from IPTables
    IPT_PORTS=( $(iptables-save | grep Split-Gateway | grep -oP '(?<=--sport )[0-9]{1,5}') )
    IPT_PROTO=( $(iptables-save | grep Split-Gateway | grep -oP '(?<=-p )(tcp|udp)') )
    for i in "${!IPT_PORTS[@]}"; do 
        if [[ -z "${REDIRECTED_PORTS_IPT}" ]]; then 
            REDIRECTED_PORTS_IPT=$(echo "${IPT_PORTS[$i]}/${IPT_PROTO[$i]}")
        else
            REDIRECTED_PORTS_IPT=$(echo "${REDIRECTED_PORTS_IPT}
${IPT_PORTS[$i]}/${IPT_PROTO[$i]}")
        fi
    done

    # Get opened ports from UFW
    if [ $REGEX_IFACE_EXPLICIT = false ]; then
        REGEX="^[[:digit:]]{1,5}/(tcp|udp)( on ${EXTERNAL_INTERFACE} [[:space:]]* ALLOW | [[:space:]]* ALLOW)[[:space:]]* Anywhere [[:space:]]*$"
    else 
        REGEX="^[[:digit:]]{1,5}/(tcp|udp) on ${EXTERNAL_INTERFACE} [[:space:]]* ALLOW [[:space:]]* Anywhere [[:space:]]*$" 
    fi
    OPENED_PORTS_UFW=$(ufw status | egrep "${REGEX}" | cut -d' ' -f1)

    PORTS_TO_OPEN=diff -wB <(echo "$REDIRECTED_PORTS_IPT") <(echo "$OPENED_PORTS_UFW") | grep -oP '^>.*' | cut -d' ' -f2
    PORTS_TO_CLOSE=diff -wB <(echo "$REDIRECTED_PORTS_IPT") <(echo "$OPENED_PORTS_UFW") | grep -oP '^<.*' | cut -d' ' -f2

    if [[ -z "${PORTS_TO_OPEN}" ]]; then 
        for line in ${PORTS_TO_OPEN}; do
            IFS="/" read -r PORT PROTOCOL <<< ${line}
            iptables -t mangle -A OUTPUT ! -d ${NETWORK} -p ${PROTOCOL} --sport ${PORT} -j MARK --set-mark 1 -m comment --comment 'Split-Gateway'
            if [ $REDIRECT_PORT_ON_ROUTER = true ]; then 
                upnpc -a `ip -4 addr show ${EXTERNAL_INTERFACE}  | grep -oP '(?<=inet\s)\d+(\.\d+){3}'` ${PORT} ${PORT} ${PROTOCOL,,}
            fi
        done
    fi

    if [[ -z "${PORTS_TO_CLOSE}" ]]; then 
        for line in ${PORTS_TO_CLOSE}; do
            IFS="/" read -r PORT PROTOCOL <<< ${line}
            iptables -t mangle -D OUTPUT ! -d ${NETWORK} -p ${PROTOCOL} --sport ${PORT} -j MARK --set-mark 1 -m comment --comment 'Split-Gateway'
            if [ $REDIRECT_PORT_ON_ROUTER = true ]; then 
                upnpc -d ${PORT} ${PROTOCOL,,} ${EXTERNAL_GATEWAY}
            fi        
        done
    fi
}

function teardown {
    # Delete all 'Split-Gateway' IPTables rules and Portforwarding
    IPT_PORTS=( $(iptables-save | grep Split-Gateway | grep -oP '(?<=--sport )[0-9]{1,5}') )
    IPT_PROTO=( $(iptables-save | grep Split-Gateway | grep -oP '(?<=-p )(tcp|udp)') )
    for i in "${!IPT_PORTS[@]}"; do 
        iptables -t mangle -D OUTPUT ! -d ${NETWORK} -p ${IPT_PROTO[$i],,} --sport ${IPT_PORTS[$i]} -j MARK --set-mark 1 -m comment --comment 'Split-Gateway'
        if [ $REDIRECT_PORT_ON_ROUTER = true ]; then 
            upnpc -d ${IPT_PORTS[$i]} ${IPT_PROTO[$i],,} ${EXTERNAL_GATEWAY}
        fi
    done

    # Delete ip rules
    while ip rule delete table split_gateway 2>/dev/null; do true; done; do true; done

    # Delete ip route
    ip route flush split_gateway
    if ! grep -Fxq "101 split_gateway" /etc/iproute2/rt_tables; then
        sed -i "/^101 split_gateway/d" /etc/iproute2/rt_tables
    fi
}       

case $1 in
    start)
        init()
        reload()
        ;;
    stop) 
        teardown()
        ;;
    reload)
        reload()
        ;;
    *)
        echo "Unkown argument: $1"
        echo "Known arguments: start, stop, reload"
        exit 1
        ;;
esac

exit 0
