# Overview

Simple script to generate OpenVPN 2.6 config automatically.

Requirements:
- wget
- sed

# Usage

Open script for edit and set three variables at the top of the file:
- `CA_CN` - CA common name
- `CLIENTS` - number of clients
- `SERVER_HOST` - IP or domain name of the server

Save script, run `./generate-openvpn-config.sh`.
Script generates server and client config files. Files have name like
`${CA_CN}-(server|client)-[0-9]+.conf`.
