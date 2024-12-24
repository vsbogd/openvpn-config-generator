#!/bin/bash

# OpenVPN configuration generator.
# Copyright (C) 2024 Vitaly Bogdanov
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

#H 
#H Generate an OpenVPN server and client configurations.
#H 
#H Usage: openvpn-generate-config.sh -c <cn> -n <count> -s <server>
#H          [-d <days>] [-r]
#H 
#H   -c <ca>        Central authority common name, no spaces
#H   -n <count>     Number of clients to generate
#H   -s <server>    Domain name or ip address of the server
#H   -d <days>      CA/client certificate validity period, 10 years by default
#H   -r             Route internet traffic via VPN server
#H 

set -eu

show_help() {
    grep -e '^#H ' $0 | sed 's/^#H //'
}

DAYS=3653
ROUTING=0

while getopts 'c:n:s:d:r' opt; do
    case "$opt" in
        c) CA_CN="$OPTARG"
            ;;
        n) CLIENTS="$OPTARG"
            ;;
        s) SERVER_HOST="$OPTARG"
            ;;
        d) DAYS="$OPTARG"
            ;;
        r) ROUTING=1
            ;;
        *) show_help
            exit 1
            ;;
    esac
done

# Setup local environment #########################################

if test -z "${CA_CN}" -o -z "${CLIENTS}" -o -z "${SERVER_HOST}" ; then
    show_help
    exit 1
fi

if ! command -v wget >/dev/null; then
    echo "Please install wget tool"
    exit 1
fi
if ! command -v sed >/dev/null; then
    echo "Please install sed tool"
    exit 1
fi

echo -n "Please enter CA private key password (at least 4 characters): "
read CA_PASS

CONFIG_DIR=`pwd`
EASYRSA_VER=3.2.1

EASYRSA_DIR_NAME=EasyRSA-${EASYRSA_VER}

if ! test -d ${EASYRSA_DIR_NAME} ; then
    if ! test -f ${EASYRSA_DIR_NAME}.tgz ; then
        wget -O ${EASYRSA_DIR_NAME}.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VER}/${EASYRSA_DIR_NAME}.tgz
    fi
    rm -rf ${EASYRSA_DIR_NAME}
    tar xzf ./${EASYRSA_DIR_NAME}.tgz
fi

# Generate keys and certificates ########################

cd ${EASYRSA_DIR_NAME}

PKI=`pwd`/pki
EASYRSA="./easyrsa --batch"

${EASYRSA} init-pki
echo -e "${CA_PASS}\n${CA_PASS}" | ${EASYRSA} --days=${DAYS} --req-cn=${CA_CN} build-ca
${EASYRSA} gen-dh
TLS_AUTH=${PKI}/${CA_CN}-tls-auth.key
openvpn --genkey secret ${TLS_AUTH}

CA_CRT=${PKI}/ca.crt
CA_KEY=${PKI}/private/ca.key
DH=${PKI}/dh.pem

ENTITY_NAME=()
CLIENT_CN=()
CLIENT_KEY=()
CLIENT_INLINE=()
CLIENT_CRT=()
for i in $(seq 0 $CLIENTS); do
    if test 0 -eq $i; then
        NAME="${CA_CN}-server-${i}"
        ROLE=server
    else
        NAME="${CA_CN}-client-${i}"
        ROLE=client
    fi

    CLIENT_CN=${NAME}
    ENTITY_NAME[$i]=${NAME}

    ${EASYRSA} --req-cn=${CLIENT_CN} --nopass gen-req ${NAME}
    CLIENT_REQ=${PKI}/reqs/${NAME}.req
    CLIENT_KEY[$i]=${PKI}/private/${NAME}.key

    ${EASYRSA} --passin=pass:${CA_PASS} --days=${DAYS} sign-req ${ROLE} ${NAME}
    CLIENT_INLINE[$i]=${PKI}/inline/private/${NAME}.inline
    CLIENT_CRT[$i]=${PKI}/issued/${NAME}.crt
done

cd ..

# Generate configs #########################

inline() {
    echo "<$1>"
    cat "$2"
    echo "</$1>"
}

after() {
    sed "1,/$1/d"
}

before() {
    sed -n "/$1/q;p"
}

for i in $(seq 0 $CLIENTS); do
    if test 0 -eq $i; then
        NAME=${CA_CN}
        SOURCE="${CONFIG_DIR}/server.conf"
        IS_SERVER=1
    else
        NAME=${ENTITY_NAME[$i]}
        SOURCE="${CONFIG_DIR}/client.conf"
        IS_SERVER=0
    fi

    CONFIG="${NAME}.conf"

    {
        if test 1 -eq ${IS_SERVER} ; then
            cat "${SOURCE}" | before "^ca "
        else
            cat "${SOURCE}" | before "^remote "
            echo "remote ${SERVER_HOST} 1194"
            cat "${SOURCE}" | after "^remote " | before "^ca "
        fi

        inline ca "${CA_CRT}"
        inline cert "${CLIENT_CRT[$i]}"
        inline key "${CLIENT_KEY[$i]}"

        if test 1 -eq ${IS_SERVER} ; then

            cat "${SOURCE}" | after "^key " | before "^dh "
            inline dh "${DH}"

            cat "${SOURCE}" | after "^dh " | before "^;tls-auth "
            inline tls-auth "${TLS_AUTH}"
            echo "key-direction 0"
            cat "${SOURCE}" | after "^;tls-auth "

            if test 1 -eq ${ROUTING} ; then
                cp up ./${NAME}.up
                echo -e "\n"
                echo "# Allow running scripts"
                echo "script-security 2"
                echo "# Setup traffic routing and NAT"
                echo "up /etc/openvpn/server/${NAME}.up"
            fi
        else
            cat "${SOURCE}" | after "^key " | before ";tls-auth "
            inline tls-auth "${TLS_AUTH}"
            echo "key-direction 1"
            cat "${SOURCE}" | after ";tls-auth "

            if test 1 -eq ${ROUTING} ; then
                echo -ne "\n"
                echo "# Replace default route by VPN server, keep DHCP using old route"
                echo "redirect-gateway def1 bypass-dhcp"
                echo "# Use Cloudflare DNS instead of local network DNS"
                echo "# (see # https://developers.cloudflare.com/1.1.1.1/ip-addresses/)"
                echo "dhcp-option dns 1.1.1.1"
            fi
        fi
    } >"${CONFIG}"

done

# Print setup instructions ##########################

SERVERDIR=/etc/openvpn/server
SERVERCONF=${CA_CN}.conf
SERVERUP=${CA_CN}.up
cat <<EOF
#################################################

1. Server setup

Copy ${CA_CN}.* files on your server host and run:

sudo chown root:root ${SERVERCONF}
sudo mv ${SERVERCONF} ${SERVERDIR}/
sudo chmod 0600 ${SERVERDIR}/${SERVERCONF}

If you have specified -r parameter to route traffic
then additionally run:

sudo chown root:root ${SERVERUP}
sudo mv ${SERVERUP} ${SERVERDIR}/
sudo chmod 0744 ${SERVERDIR}/${SERVERUP}

Run:

systemctl enable openvpn openvpn-server@${CA_CN}
systemctl start openvpn openvpn-server@${CA_CN}

To enable OpenVPN server auto start and start it.

2. Client setup

Run:

openvpn ${CA_CN}-client-*.conf

EOF
