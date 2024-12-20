# Overview

Simple script to generate OpenVPN 2.6 config automatically. This script keeps
CA, server and client keys at the same EasyRSA directory. Such setup is
considered insecure but this script is meant to be used in a simple scenarios
when one person can own all of keys.

The following tools are required by the script:
- wget
- sed

# Usage

Run `openvpn-generate-configs.sh` with at least following parameters:
- `-c ca` - Central authority common name
- `-n count` - Number of clients to generate
- `-s server` - Domain name or ip address of the server

Optionally use options:
- `-d days` - CA/client certificate validity period, 10 years by default

Script generates server and client config files. Resulting files  have name
like `${CA_CN}-(server|client)-[0-9]+.conf`. Configs contains all the
certificate and keys needed. Tune configs if necessary then copy configs on
target machines and run OpenVPN.
