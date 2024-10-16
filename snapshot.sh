#!/bin/bash

# Colors for text output
GREEN='\033[0;32m'
NC='\033[0m' # No color

# Welcome message
echo -e "${GREEN}Welcome to the Story Protocol Snapshot Downloader!${NC}"

# Step 1: Install necessary dependencies
echo -e "${GREEN}Installing necessary dependencies (curl, lz4, tar)...${NC}"
sudo apt-get update -y
sudo apt-get install -y curl lz4 tar

# Check if the user is root and set directory paths accordingly
if [ "$EUID" -eq 0 ]; then
    echo "You are running this script as root."
    DAEMON_HOME="/root/.story/story"
    GETH_HOME="/root/.story/geth/iliad/geth"
else
    USER_NAME=$(whoami)
    echo "You are running this script as user: $USER_NAME"
    DAEMON_HOME="/home/$USER_NAME/.story/story"
    GETH_HOME="/home/$USER_NAME/.story/geth/iliad/geth"
fi

# Define service names
echo -e "${GREEN}By default, the services are named 'story' and 'geth'.${NC}"
echo "If this is correct, press Enter. Otherwise, please input your custom service names."

read -p "Enter the Story service name (e.g., 'story' or 'story.service'): " story_service_name
story_service_name=${story_service_name:-story} # Default to 'story' if no input

read -p "Enter the Geth service name (e.g., 'geth' or 'geth.service'): " geth_service_name
geth_service_name=${geth_service_name:-geth} # Default to 'geth' if no input

# Remove any .service suffix entered and add it back to avoid confusion
if [[ ! $story_service_name == *.service ]]; then
    story_service_name="$story_service_name.service"
fi

if [[ ! $geth_service_name == *.service ]]; then
    geth_service_name="$geth_service_name.service"
fi

# Step 2: Stop the services
echo "Stopping services $story_service_name and $geth_service_name..."
sudo systemctl stop $story_service_name
sudo systemctl stop $geth_service_name

# Step 3: Backup priv_validator_state.json
echo "Creating backup of priv_validator_state.json..."
cp $DAEMON_HOME/data/priv_validator_state.json $DAEMON_HOME/priv_validator_state.json.backup

# Step 4: Remove old data directories
echo "Deleting old data directories..."
rm -rf $DAEMON_HOME/data
rm -rf $GETH_HOME/chaindata

# Step 5: Select snapshot type
echo -e "${GREEN}Which snapshot would you like to download?${NC}"
echo "1) Pruned"
echo "2) Archive"
read -p "Enter the number (1 for Pruned, 2 for Archive): " snapshot_choice

# Step 6: Download and extract snapshots
if [ "$snapshot_choice" -eq 1 ]; then
    echo "Downloading Pruned snapshot..."
    curl http://46.4.114.99/story_snapshot_pruned.tar.lz4 | lz4 -dc - | tar -xf - -C $DAEMON_HOME
    curl http://46.4.114.99/geth_snapshot.tar.lz4 | lz4 -dc - | tar -xf - -C $GETH_HOME
elif [ "$snapshot_choice" -eq 2 ]; then
    echo "Downloading Archive snapshot..."
    curl http://46.4.114.99/archive_snapshots/story_snapshot_archive.tar.lz4 | lz4 -dc - | tar -xf - -C $DAEMON_HOME
    curl http://46.4.114.99/archive_snapshots/geth_snapshot.tar.lz4 | lz4 -dc - | tar -xf - -C $GETH_HOME
else
    echo "Invalid choice, exiting..."
    exit 1
fi

# Step 7: Restore the backup of priv_validator_state.json
echo "Restoring priv_validator_state.json..."
mv $DAEMON_HOME/priv_validator_state.json.backup $DAEMON_HOME/data/priv_validator_state.json

# Step 8: Start the services
echo "Starting services $story_service_name and $geth_service_name..."
sudo systemctl start $story_service_name
sudo systemctl start $geth_service_name

echo -e "${GREEN}Snapshot download and service restart completed!${NC}"
