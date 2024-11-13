#!/bin/bash

ORANGE='\033[0;33m'
NC='\033[0m'
GREEN='\033[1;32m'

echo -e "${ORANGE} ____ _____ ___  ______   __ ${NC}"
echo -e "${ORANGE}/ ___|_   _/ _ \\|  _ \\ \\ / / ${NC}"
echo -e "${ORANGE}\\___ \\ | || | | | |_) \\ V /  ${NC}"
echo -e "${ORANGE} ___) || || |_| |  _ < | |   ${NC}"
echo -e "${ORANGE}|____/ |_| \\___/|_| \\_\\|_|   ${NC}"

echo "=============================================="
echo "Welcome to the Story Protocol Node Installer"
echo "=============================================="
echo "Please ensure you have sudo privileges for this installation."

echo -e "${GREEN}"
read -p "Do you want to proceed with the full installation and launch of the Story Protocol node? (yes/no): " proceed
echo -e "${NC}"

if [[ "$proceed" != "yes" ]]; then
    echo "Installation aborted by the user."
    exit 1
fi

sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt install git -y
sudo apt install fail2ban -y
sudo apt-get install build-essential -y
sudo apt-get install jq -y
sudo apt install wget jq unzip git build-essential pkg-config libssl-dev -y
sudo apt install curl lz4 -y
sudo apt install cmake pkg-config libssl-dev git gcc build-essential clang -y
sudo apt install libfuse-dev -y

GO_VERSION="1.23.2"
wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
source ~/.profile
export PATH=$PATH:/usr/local/go/bin
sudo ln -s /usr/local/go/bin/go /usr/local/bin/go
sudo rm go$GO_VERSION.linux-amd64.tar.gz

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

echo -e "${GREEN}"
read -p "Do you want to install and configure a firewall to restrict ports? (yes/no): " install_firewall
echo -e "${NC}"

if [[ "$install_firewall" == "yes" ]]; then
    sudo apt install ufw -y
    echo -e "${GREEN}"
    read -p "Enter your SSH port (default is 22): " ssh_port
    echo -e "${NC}"
    ssh_port=${ssh_port:-22}
    sudo ufw allow $ssh_port/tcp
    sudo ufw allow 8545/tcp
    sudo ufw allow 8546/tcp
    sudo ufw allow 30303/tcp
    sudo ufw allow 30303/udp
    sudo ufw allow 26656/tcp
    sudo ufw allow 26657/tcp
    sudo ufw allow 26660/tcp
    sudo ufw enable
fi

wget -O geth https://github.com/piplabs/story-geth/releases/download/v0.10.0/geth-linux-amd64
sudo chmod +x $HOME/geth
sudo mv $HOME/geth /usr/bin/

wget -O story https://github.com/piplabs/story/releases/download/v0.12.1/story-linux-amd64
sudo chmod +x $HOME/story
sudo mv $HOME/story /usr/bin/

echo -e "${GREEN}"
read -p "Please enter your node moniker: " NODE_MONIKER
echo -e "${NC}"
story init --network iliad --moniker ${NODE_MONIKER}

echo -e "${GREEN}"
read -p "Do you want to install Cosmovisor for automatic upgrades? (yes/no): " install_cosmovisor
echo -e "${NC}"

if [[ "$install_cosmovisor" == "yes" ]]; then
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
    mkdir -p ${HOME}/.story/story/cosmovisor/genesis/bin
    mkdir -p ${HOME}/.story/story/cosmovisor/upgrades/ && sudo touch ${HOME}/.story/story/cosmovisor/upgrades/upgrade-info.json
    cp $(which story) ${HOME}/.story/story/cosmovisor/genesis/bin/
    ln -s -T ${HOME}/.story/story/cosmovisor/genesis ${HOME}/.story/story/cosmovisor/current
    mkdir -p ${HOME}/.story/story/cosmovisor/upgrades/v0.12.1/bin/
    cp $(which story) ${HOME}/.story/story/cosmovisor/upgrades/v0.12.1/bin/

    echo "export PATH=\$PATH:$HOME/go/bin" >> ~/.profile
    source ~/.profile

    if [ "$EUID" -eq 0 ]; then
        USERNAME="root"
        DAEMON_HOME="/root/.story/story"
        COSMOVISOR_PATH="/root/go/bin/cosmovisor"
    else
        USERNAME=$(whoami)
        DAEMON_HOME="/home/$USERNAME/.story/story"
        COSMOVISOR_PATH="/home/$USERNAME/go/bin/cosmovisor"
    fi

    sudo bash -c "cat > /etc/systemd/system/story.service << EOF
[Unit]
Description=Cosmovisor Story Service
After=network-online.target

[Service]
User=$USERNAME
WorkingDirectory=$DAEMON_HOME
Environment=DAEMON_NAME=story
Environment=DAEMON_RESTART_AFTER_UPGRADE=true
Environment=DAEMON_HOME=$DAEMON_HOME
Environment=UNSAFE_SKIP_BACKUP=true
Environment=DAEMON_LOG_BUFFER_SIZE=512
Environment=DAEMON_ALLOW_DOWNLOAD_BINARIES=false
ExecStart=$COSMOVISOR_PATH run run
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF"

else
    if [ "$EUID" -eq 0 ]; then
        USERNAME="root"
        DAEMON_HOME="/root/.story/story"
        EXEC_START_PATH="/usr/bin/story"
    else
        USERNAME=$(whoami)
        DAEMON_HOME="/home/$USERNAME/.story/story"
        EXEC_START_PATH="/usr/bin/story"
    fi

    sudo bash -c "cat > /etc/systemd/system/story.service << EOF
[Unit]
Description=Execution service
After=network-online.target

[Service]
User=$USERNAME
WorkingDirectory=$DAEMON_HOME
ExecStart=$EXEC_START_PATH run
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF"
fi

sudo bash -c "cat > /etc/systemd/system/geth.service << EOF
[Unit]
Description=Execution service
After=network-online.target

[Service]
User=$(whoami)
ExecStart=$(which geth) --iliad --syncmode full --http --http.api eth,net,web3,engine --http.vhosts '*' --http.addr 0.0.0.0 --http.port 8545 --ws --ws.api eth,web3,net,txpool --ws.addr 0.0.0.0
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF"

sudo apt install curl jq lz4 unzip -y
curl https://server-1.itrocket.net/testnet/story/story_2024-11-13_522159_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.story/story
mkdir -p $HOME/.story/geth/iliad/geth/
curl https://server-1.itrocket.net/testnet/story/geth_story_2024-11-13_522159_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.story/geth/odyssey/geth

wget -O $HOME/.story/story/config/genesis.json https://server-3.itrocket.net/testnet/story/genesis.json
wget -O $HOME/.story/story/config/addrbook.json https://server-3.itrocket.net/testnet/story/addrbook.json

sudo systemctl daemon-reload
sudo systemctl enable story.service
sudo systemctl restart story.service
sudo systemctl enable geth.service
sudo systemctl restart geth.service

echo "=============================================="
echo "The Story Protocol node installation is complete."
echo "Your node is now syncing."
echo "=============================================="
