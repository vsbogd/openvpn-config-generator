# Overview

Script generates server and required number of client configuration files.
Generated configurations inline all the keys and certificate required, thus
copying a single file is enough to run server or client. 

Script supports OpenVPN version 2.6 and built on top of [EasyRSA
3](https://github.com/OpenVPN/easy-rsa). Configuration includes CA certificate,
server keys and certificates, client keys and certificates, Diffie-Hellman
parameters and tls-auth key. CA, server and client keys are kepts at the same
EasyRSA directory. Such setup is considered insecure but it is meant to be used
in a simple scenario when a single person may own all of keys.

The following tools are required, to run the script:
- [wget](https://www.gnu.org/software/wget/) - to download EasyRSA release automatically
- [sed](https://www.gnu.org/software/sed/) - to manipulate script files
- [OpenVPN](https://openvpn.net/community/) - to generate tls-auth key

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
`${CA_CN}-client-[0-9]+.conf` and `${CA_CN}.conf`. Server and client keys are
not protected with password. Use `openvpn-change-key-pass.sh <config>` to set
or change the password. Usually it is required for a client only because server
should be started automatically. Script prints short setup instructions after
generation.
