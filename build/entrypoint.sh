#!/bin/sh

# --------------------------------------------------
#                       UTILS                       
# --------------------------------------------------

# ----------------  tor functions  -----------------

# Generates the tor config block 
mk_tor_backend_cfg () {
    local start="${1}"
    local n="${2}"

    if [ "${#}" -ne 2 ]; then
        echo "Bad mk_tor_backend_cfg function usage, exiting ..."
        exit 1
    fi

    local p
    for p in $( seq "${start}" "$(( start + n - 1 ))" ); do
        echo "SocksPort 127.0.0.1:${p}"
    done
}

# --------------  haproxy functions  ---------------

# Generates the haproxy backend config, given a torrc file
# Note that the indentation level expects the default haproxy.cfg file.
# If the latter is user-specified, this might need to be corrected.
mk_haproxy_backend_cfg () {
    local torrc="${1}"
    
    if [ "${#}" -ne 1 ]; then
        echo "Bad mk_haproxy_backend_cfg function usage, exiting ..."
        exit 1
    fi

    if [ -f "${torrc}" ]; then
        local tor_backend=$(cat "${torrc}" | grep ^SocksPort | awk '{print $2}')
        if [ -z "${tor_backend}" ]; then
            echo "No backend specification found in ${torrc}, exiting ..."
            exit 1
        else
            local addr
            for addr in $(echo "${tor_backend}"); do
                local port="${addr#*:}"
                echo "  server tor${port} ${addr}"
            done
        fi
    else
        echo "${torrc} does not exist, exiting ..."
        exit 1
    fi
}

set_balancing_algorithm () {
    local config_template="${1}"
    local algorithm="${2}"

    if [ "${#}" -ne 2 ]; then
        echo "Bad set_balancing_algorithm function usage, exiting ..."
        exit 1
    fi

    if [ "${algorithm}" = "roundrobin" ] || [ "${algorithm}" = "leastconn" ] || [ "${algorithm}" = "source" ]; then
        sed -i "s/<balancing_algorithm_placeholder>/${algorithm}/g" "${config_template}"
    else
        echo "Invalid balancing algorithm : ${algorithm}"
        exit 1
    fi
}
# --------------------------------------------------
#                        MAIN                       
# --------------------------------------------------

# --------------  args and env vars  ---------------
LISTENERS="${LISTENERS-10}"

BALANCING_ALGORITHM="${BALANCING_ALGORITHM-roundrobin}"
HAPROXY_CONF_TEMPLATE="/usr/local/etc/haproxy/haproxy.tpl"
HAPROXY_CONF="/usr/local/etc/haproxy/haproxy.cfg"

TOR_CONF="/etc/tor/torrc"
TOR_CONF_PREFIX="/etc/tor/torrc.pfx"

set -e
# ------------------  tor setup  -------------------
echo
echo "--------------------------------------------------"
echo "                    tor setup                     "
echo "--------------------------------------------------"
echo

if ! mount | grep -F "${TOR_CONF}" | grep -vF "${TOR_CONF_PREFIX}" > /dev/null; then
    echo "${TOR_CONF} is not mounted"
    echo > "${TOR_CONF}" # Clean file in case same container in ran more than once
    if [ -e "${TOR_CONF_PREFIX}" ]; then
        echo "${TOR_CONF_PREFIX} is mounted"
        cat "${TOR_CONF_PREFIX}" | grep -v ^RunAsDaemon > "${TOR_CONF}"
        echo >> "${TOR_CONF}"
    fi
    echo "RunAsDaemon 1" >> "${TOR_CONF}"
    mk_tor_backend_cfg 9050 "${LISTENERS}" >> "${TOR_CONF}"
else
    echo "${TOR_CONF} is mounted"
fi

echo -e "\n----------------  /etc/tor/torrc  ----------------\n"
cat "${TOR_CONF}"
echo -e "\n--------------------------------------------------\n"

tor -f "${TOR_CONF}"

# ----------------  haproxy setup  -----------------
echo
echo "--------------------------------------------------"
echo "                  haproxy setup                   "
echo "--------------------------------------------------"
echo
if ! mount | grep -F "${HAPROXY_CONF}" > /dev/null; then
    echo "${HAPROXY_CONF} is not mounted"
    cp "${HAPROXY_CONF_TEMPLATE}" "${HAPROXY_CONF}"
    set_balancing_algorithm "${HAPROXY_CONF}" "${BALANCING_ALGORITHM}"
    mk_haproxy_backend_cfg "${TOR_CONF}" >> "${HAPROXY_CONF}"
else
    echo "${HAPROXY_CONF} is mounted"
fi
echo >> "${HAPROXY_CONF}" # Haproxy throws error if last line misses line feed ?

echo -e "\n------  /usr/local/etc/haproxy/haproxy.cfg  ------\n"
cat "${HAPROXY_CONF}"
echo -e "\n--------------------------------------------------\n"

haproxy -f "${HAPROXY_CONF}"

