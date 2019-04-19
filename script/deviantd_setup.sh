#!/bin/bash
# Download latest node and install.
devlink=`curl -s https://api.github.com/repos/Deviantcoin/Source/releases/latest | grep browser_download_url | grep x86_64-linux-gnu | cut -d '"' -f 4`
`
mkdir -p /tmp/deviant
cd /tmp/deviant
curl -Lo deviant-4.0.0-x86_64-linux-gnu.tar.gz $devlink
tar -xzf deviant-4.0.0-x86_64-linux-gnu.tar.gz
sudo mv ./bin/* /usr/local/bin
cd
rm -rf /tmp/deviant
mkdir ~/.deviant

# Setup configuration for node.
rpcuser=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
rpcpassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')
cat >~/.deviant/deviant.conf <<EOL
rpcuser=$rpcuser
rpcpassword=$rpcpassword
daemon=1
txindex=1
EOL

# Start node.
deviantd
