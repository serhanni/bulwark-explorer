#!/bin/bash

installNodeAndYarn () {
    echo "Installing nodejs and yarn..."
    sudo curl -sL https://deb.nodesource.com/setup_8.x | sudo bash -
    sudo apt-get install -y nodejs npm
    sudo curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    sudo echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt-get update -y
    sudo apt-get install -y yarn
    sudo npm install -g pm2
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo chown -R explorer:explorer /home/explorer/.config
    clear
}

installNginx () {
    echo "Installing nginx..."
    sudo apt-get install -y nginx
    sudo rm -f /etc/nginx/sites-available/default
    sudo cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    #server_name explorer.bulwarkcrypto.com;
    server_name _;

    gzip on;
    gzip_static on;
    gzip_disable "msie6";

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript application/vnd.ms-fontobject application/x-font-ttf font/opentype image/svg+xml image/x-icon;

    location / {
        proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
    }

    #listen [::]:443 ssl ipv6only=on; # managed by Certbot
    #listen 443 ssl; # managed by Certbot
    #ssl_certificate /etc/letsencrypt/live/explorer.bulwarkcrypto.com/fullchain.pem; # managed by Certbot
    #ssl_certificate_key /etc/letsencrypt/live/explorer.bulwarkcrypto.com/privkey.pem; # managed by Certbot
    #include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    #ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

#server {
#    if ($host = explorer.bulwarkcrypto.com) {
#        return 301 https://\$host\$request_uri;
#    } # managed by Certbot
#
#	listen 80 default_server;
#	listen [::]:80 default_server;
#
#	server_name explorer.bulwarkcrypto.com;
#   return 404; # managed by Certbot
#}
EOL
    sudo systemctl start nginx
    sudo systemctl enable nginx
    clear
}

installMongo () {
    echo "Installing mongodb..."
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
    sudo echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.6.list
    sudo apt-get update -y
    sudo apt-get install -y --allow-unauthenticated mongodb-org
    sudo chown -R mongodb:mongodb /data/db
    sudo systemctl start mongod
    sudo systemctl enable mongod
    mongo blockex --eval "db.createUser( { user: \"$rpcuser\", pwd: \"$rpcpassword\", roles: [ \"readWrite\" ] } )"
    clear
}

installBulwark () {
    echo "Installing Deviant..."
    mkdir -p /tmp/deviant
    cd /tmp/deviant
    curl -Lo deviant.tar.gz $bwklink
    tar -xzf deviant.tar.gz
    sudo mv ./bin/* /usr/local/bin
    cd
    rm -rf /tmp/deviant
    mkdir -p /home/explorer/.deviant
    cat > /home/explorer/.deviant/deviant.conf << EOL
rpcport=52544
rpcuser=$rpcuser
rpcpassword=$rpcpassword
daemon=1
txindex=1
EOL
    sudo cat > /etc/systemd/system/deviantd.service << EOL
[Unit]
Description=deviantd
After=network.target
[Service]
Type=forking
User=explorer
WorkingDirectory=/home/explorer
ExecStart=/home/explorer/bin/deviantd -datadir=/home/explorer/.deviant
ExecStop=/home/explorer/bin/deviant-cli -datadir=/home/explorer/.deviant stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
    sudo systemctl start deviantd
    sudo systemctl enable deviantd
    echo "Sleeping for 1 hour while node syncs blockchain..."
    sleep 1h
    clear
}

installBlockEx () {
    echo "Installing BlockEx..."
    git clone https://github.com/serhanni/bulwark-explorer.git /home/explorer/blockex
    cd /home/explorer/blockex
    yarn install
    cat > /home/explorer/blockex/config.js << EOL
const config = {
  'api': {
    'host': 'http://localhost',
    'port': '3000',
    'prefix': '/api',
    'timeout': '180s'
  },
  'coinMarketCap': {
    'api': 'http://api.coinmarketcap.com/v1/ticker/',
    'ticker': 'deviantcoin'
  },
  'db': {
    'host': '127.0.0.1',
    'port': '27017',
    'name': 'blockex',
    'user': '$rpcuser',
    'pass': '$rpcpassword'
  },
  'freegeoip': {
    'api': 'https://extreme-ip-lookup.com/json/'
  },
  'rpc': {
    'host': '127.0.0.1',
    'port': '22617',
    'user': '$rpcuser',
    'pass': '$rpcpassword',
    'timeout': 12000, // 12 seconds
  }
};

module.exports = config;
EOL
    nodejs ./cron/block.js
    nodejs ./cron/coin.js
    nodejs ./cron/masternode.js
    nodejs ./cron/peer.js
    nodejs ./cron/rich.js
    clear
    cat > mycron << EOL
*/1 * * * * cd /home/explorer/blockex && ./script/cron_block.sh >> ./tmp/block.log 2>&1
*/1 * * * * cd /home/explorer/blockex && /usr/bin/nodejs ./cron/masternode.js >> ./tmp/masternode.log 2>&1
*/1 * * * * cd /home/explorer/blockex && /usr/bin/nodejs ./cron/peer.js >> ./tmp/peer.log 2>&1
*/1 * * * * cd /home/explorer/blockex && /usr/bin/nodejs ./cron/rich.js >> ./tmp/rich.log 2>&1
*/5 * * * * cd /home/explorer/blockex && /usr/bin/nodejs ./cron/coin.js >> ./tmp/coin.log 2>&1
EOL
    crontab mycron
    rm -f mycron
    pm2 start ./server/index.js
    sudo pm2 startup ubuntu
}

# Setup
echo "Updating system..."
sudo apt-get update -y
sudo apt-get install -y apt-transport-https build-essential cron curl gcc git g++ make sudo vim wget
clear

# Variables
echo "Setting up variables..."
devlink=`curl -s https://api.github.com/repos/Deviantcoin/Source/releases/latest | grep browser_download_url | grep deviant-4.0.0-x86_64-linux-gnu.tar.gz`
rpcuser=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
rpcpassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')
echo "Repo: $devlink"
echo "PWD: $PWD"
echo "User: $rpcuser"
echo "Pass: $rpcpassword"
sleep 5s
clear

# Check for blockex folder, if found then update, else install.
if [ ! -d "/home/explorer/blockex" ]
then
    installNginx
    installMongo
    installBulwark
    installNodeAndYarn
    installBlockEx
    echo "Finished installation!"
else
    cd /home/explorer/blockex
    git pull
    pm2 restart index
    echo "BlockEx updated!"
fi

