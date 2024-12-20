#!/bin/sh

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

CA_CN=MyVPN
CLIENTS=1
SERVER_HOST=127.0.0.1

CONFIG_DIR=`pwd`
EASYRSA_VER=3.2.1

EASYRSA_DIR_NAME=EasyRSA-${EASYRSA_VER}

rm -rf ${EASYRSA_DIR_NAME}
rm -rf ${CA_CN}-*

wget -O ${EASYRSA_DIR_NAME}.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VER}/${EASYRSA_DIR_NAME}.tgz
tar xzf ./${EASYRSA_DIR_NAME}.tgz

cd ${EASYRSA_DIR_NAME}

PKI=`pwd`/pki
EASYRSA="./easyrsa --batch"

${EASYRSA} init-pki
${EASYRSA} --req-cn=${CA_CN} build-ca
${EASYRSA} gen-dh

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

    ${EASYRSA} import-req ${CLIENT_REQ} ${NAME}
    ${EASYRSA} sign-req ${ROLE} ${NAME}
    CLIENT_INLINE[$i]=${PKI}/inline/private/${NAME}.inline
    CLIENT_CRT[$i]=${PKI}/issued/${NAME}.crt
done

cd ..

TMPDIR=`mktemp -d`
TMPCONF="${TMPDIR}/config"

for i in $(seq 0 $CLIENTS); do
    if test 0 -eq $i; then
        CONF=${CONFIG_DIR}/server.conf
    else
        CONF=${CONFIG_DIR}/client.conf
    fi

    cat ${CONF} | sed -n '/^ca /q;p' >${TMPCONF}

    echo "<ca>" >>${TMPCONF}
    cat ${CA_CRT} >>${TMPCONF}
    echo "</ca>" >>${TMPCONF}

    echo "<cert>" >>${TMPCONF}
    cat ${CLIENT_CRT[$i]} >>${TMPCONF}
    echo "</cert>" >>${TMPCONF}

    echo "<key>" >>${TMPCONF}
    cat ${CLIENT_KEY[$i]} >>${TMPCONF}
    echo "</key>" >>${TMPCONF}

    if test 0 -eq $i; then
        cat ${CONF} | sed '1,/^key /d' | sed -n '/^dh /q;p' >>${TMPCONF}

        echo "<dh>" >>${TMPCONF}
        cat ${DH} >>${TMPCONF}
        echo "</dh>" >>${TMPCONF}

        cat ${CONF} | sed '1,/^dh /d' >>${TMPCONF}
    else
        cat ${CONF} | sed '1,/^key /d' >>${TMPCONF}
        sed -i "s/my-server-1/${SERVER_HOST}/g" ${TMPCONF}
    fi

    cp ${TMPCONF} ./${ENTITY_NAME[$i]}.conf
    shred -u ${TMPCONF}
done
