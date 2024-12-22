#!/bin/bash

# OpenVPN key password changer.
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

## 
## Change password of the private key from OpenVPN config file.
## 
## Usage: openvpn-change-key-pass.sh config
## 
##   config     OpenVPN configuration file which contains a private key
## 

show_help() {
    grep -e '^##' $0 | sed 's/^## //'
}

umask 077

config=$1

if test -z "${config}" ; then
    show_help
    exit 1
fi

tmpdir=`mktemp -d`
tmpkey="$tmpdir/key"
tmpconf="$tmpdir/config"

cat "$config" | sed -n '/<key>/,/<\/key>/ p' \
	| tail -n +2 | head -n -1 > "$tmpkey"
openssl rsa -aes256 -in "$tmpkey" -out "$tmpkey.new"

cat "$config" | sed '/<key>/q' > "$tmpconf"
cat "$tmpkey.new" >> "$tmpconf"
cat "$config" | sed -n '/<\/key>/,$p' >> "$tmpconf"
mv "$tmpconf" "$config"

shred -u "$tmpkey" "$tmpkey.new"
rmdir "$tmpdir"
