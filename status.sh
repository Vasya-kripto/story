# Extracting RPC port from the config file
rpc_port=$(grep -m 1 -Po 'laddr = "\K[^"]+' "$HOME/.story/story/config/config.toml" | awk -F ':' '{print $3}')

# Function to check and print node status
check_node_status() {
  # Fetch local and network block heights
  local_block=$(curl -s localhost:$rpc_port/status | jq -r '.result.sync_info.latest_block_height')
  network_block=$(curl -s https://testnet.storyrpc.io/status | jq -r '.result.sync_info.latest_block_height')

  # Validate block height data
  if ! [[ "$local_block" =~ ^[0-9]+$ ]] || ! [[ "$network_block" =~ ^[0-9]+$ ]]; then
    echo -e "\033[1;35mWarning: Unable to retrieve valid block height. Retrying shortly...\033[0m"
    return 1
  fi

  # Calculate the difference in block heights
  remaining_blocks=$((network_block - local_block))
  if [ "$remaining_blocks" -lt 0 ]; then
    remaining_blocks=0
  fi

  # Display the block heights in a column format
  echo -e "\033[1;34mYour Node Block Height:\033[1;32m $local_block\033[0m"
  echo -e "\033[1;34mNetwork Block Height:\033[1;32m $network_block\033[0m"
  echo -e "\033[1;34mRemaining Blocks:\033[1;35m $remaining_blocks\033[0m"
}

# Run the check once
check_node_status
