#!/bin/bash

# Colors for text output
GREEN='\033[0;32m'
NC='\033[0m' # No color

# Welcome message
echo -e "${GREEN}Welcome to the Story Protocol Snapshot Downloader!${NC}"

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

# Ask if the user wants to stop the services
echo -e "${GREEN}Do you need to stop your Story and Geth services? (yes/no)${NC}"
echo -e "Answer 'no' if your services are already stopped and you just want to download the snapshot."
read -p "Do you need to stop your Story and Geth services? (yes/no): " stop_services

if [[ "$stop_services" == "yes" ]]; then
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

    # Stop the services
    echo "Stopping services $story_service_name and $geth_service_name..."
    sudo systemctl stop $story_service_name
    sudo systemctl stop $geth_service_name
fi

# Backup priv_validator_state.json
echo "Creating backup of priv_validator_state.json..."
cp $DAEMON_HOME/data/priv_validator_state.json $DAEMON_HOME/priv_validator_state.json.backup

# Remove old data directories
echo "Deleting old data directories..."
rm -rf $DAEMON_HOME/data
rm -rf $GETH_HOME/chaindata

# Select snapshot type
echo -e "${GREEN}Which snapshot would you like to download?${NC}"
echo "1) Pruned"
echo "2) Archive"
read -p "Enter the number (1 for Pruned, 2 for Archive): " snapshot_choice

# Download and extract snapshots
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

# Restore the backup of priv_validator_state.json
echo "Restoring priv_validator_state.json..."
mv $DAEMON_HOME/priv_validator_state.json.backup $DAEMON_HOME/data/priv_validator_state.json

# Ask if the user wants to start the services again
if [[ "$stop_services" == "yes" ]]; then
    # Ask if the user wants to restart the services
    read -p "Do you want to restart your Story and Geth services? (yes/no): " restart_services
    if [[ "$restart_services" == "yes" ]]; then
        echo "Starting services $story_service_name and $geth_service_name..."
        sudo systemctl start $story_service_name
        sudo systemctl start $geth_service_name
        echo -e "${GREEN}Snapshot download and service restart completed!${NC}"
    else
        echo -e "${GREEN}Snapshot download completed. You can now manually start your services.${NC}"
    fi
else
    echo -e "${GREEN}Snapshot download completed. You can now start your services.${NC}"
fi
