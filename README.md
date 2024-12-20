# Overview

Simple script to generate OpenVPN 2.6 config automatically.

Requirements:
- wget
- sed

# Usage

Run `openvpn-generate-configs.sh` with at least following parameters:
- `-c <name>` - set CA common name
- `-n <count>` - number of clients to generate
- `-s <server>` - IP or domain name of the server

Script generates server and client config files. Resulting files  have name
like `${CA_CN}-(server|client)-[0-9]+.conf`.
