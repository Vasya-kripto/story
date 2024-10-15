#!/bin/bash

# Step 1: Export the private key
echo "Exporting the private key..."
story validator export --export-evm-key

# Step 2: Run "story validator export" and extract the EVM Public Key
evm_public_key=$(story validator export | grep -m 1 "EVM Public Key")

# Extract the private key from the file
if [ -f "$HOME/.story/story/config/private_key.txt" ]; then
    private_key=$(grep -oP '(?<=^PRIVATE_KEY=).*' "$HOME/.story/story/config/private_key.txt")
    wallet_private_key="0x$private_key"

    # Display the public and private keys for the user with an explanation
    echo -e "------------------------------------------------------------------------------"
    echo -e "\033[1;32mpublic key: $evm_public_key\033[0m"
    echo -e "\033[1;36mprivate key: $wallet_private_key\033[0m"
    echo -e "\033[1;33mTo create a validator, you need to send tokens to your EVM public key from another wallet, or import your private key into Metamask/Rabby and request tokens from the faucet.\033[0m"
    echo -e "\033[1;32m>>>>> https://docs.story.foundation/docs/faucet <<<<<\033[0m"
    echo -e "------------------------------------------------------------------------------"
else
    echo "Error: Private key file not found!"
    exit 1
fi

# Ask if the user has obtained tokens
echo
read -p "Have you obtained tokens? (yes/no): " has_tokens

if [[ "$has_tokens" != "yes" ]]; then
    echo "Please obtain tokens before proceeding."
    exit 1
fi

# Step 3: Move the private key to the .env file
echo "Moving the private key to $HOME/.env"
mv "$HOME/.story/story/config/private_key.txt" "$HOME/.env"

# Step 4: Create the validator
story validator create --stake 1000000000000000000
