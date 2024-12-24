# Overview

Simple script to generate OpenVPN 2.6 config automatically. This script keeps
CA, server and client keys at the same EasyRSA directory. Such setup is
considered insecure but this script is meant to be used in a simple scenarios
when one person can own all of keys.

The following tools are required by the script:
- bash
- wget
- sed
- openvpn

# Usage

Run `openvpn-generate-configs.sh` with at least following parameters:
- `-c <ca>` - Central authority common name, no spaces
- `-n <count>` - Number of clients to generate
- `-s <server>` - Domain name or ip address of the server

Optionally use options:
- `-d <days>` - CA/client certificate validity period, 10 years by default
- `-r` -  Route internet traffic via VPN server

Script generates server and client config files. The only password you need to
enter during the process is a new CA key password. Resulting files have names
`${CA_CN}-client-[0-9]+.conf` and `${CA_CN}.conf`. Configs contain all the
certificates and keys needed. Server and client keys are not protected with
password. Use `openvpn-change-key-pass.sh <config>` to set or change the
password. Usually it is required for a client only because server should be
started automatically. Script prints short setup instructions after generation.
