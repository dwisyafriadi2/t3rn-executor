#!/bin/bash

# Function to print the banner
print_banner() {
  clear
  echo -e """
    ____                       
   / __ \\____ __________ ______
  / / / / __ \`/ ___/ __ \`/ ___/
 / /_/ / /_/ (__  ) /_/ / /    
/_____/_\\__,_/____/\\__,_/_/      

    ____                       __
   / __ \\___  ____ ___  __  __/ /_  ______  ____ _
  / /_/ / _ \\/ __ \`__ \\/ / / / / / / / __ \\/ __ \`/
 / ____/  __/ / / / / / /_/ / / /_/ / / / / /_/ / 
/_/    \\___/_/ /_/ /_/\\__,_/_/\\__,_/_/ /_/\\__, /  
                                         /____/    

====================================================
     Automation         : Auto Install Node 
     Telegram Channel   : @dasarpemulung
     Telegram Group     : @parapemulung
====================================================
"""
}

# Function to display process message
process_message() {
    echo -e "\n\e[42m$1...\e[0m\n" && sleep 1
}

# Function to check root/sudo and set home directory
check_root() {
    process_message "Checking root privileges"
    if [ "$EUID" -ne 0 ]; then
        HOME_DIR="/home/$USER"
        echo "Running as user. Files will be saved to $HOME_DIR."
    else
        HOME_DIR="/root"
        echo "Running as root. Files will be saved to $HOME_DIR."
    fi
}

# Function to download the latest Executor binary
# Function to download the latest Executor binary
download_executor() {
    process_message "Downloading the latest Executor binary"
    # Fetch the latest release tag from GitHub API
    LATEST_TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep tag_name | cut -d '"' -f 4)
    # Determine the OS type
    OS_TYPE=$(uname -s)
    if [ "$OS_TYPE" == "Linux" ]; then
        FILE_NAME="executor-linux-$LATEST_TAG.tar.gz"
    elif [ "$OS_TYPE" == "Darwin" ]; then
        FILE_NAME="executor-macosx-$LATEST_TAG.tar.gz"
    else
        echo "Unsupported OS: $OS_TYPE"
        exit 1
    fi
    DOWNLOAD_URL="https://github.com/t3rn/executor-release/releases/download/$LATEST_TAG/$FILE_NAME"
    curl -L $DOWNLOAD_URL -o "$HOME_DIR/$FILE_NAME"
    process_message "Extracting Executor binary"
    tar -xzf "$HOME_DIR/$FILE_NAME" -C "$HOME_DIR"
    # Grant execute permissions to the executor binary
    chmod +x "$HOME_DIR/executor/executor"
    echo "File extracted and permissions set. Navigate to the 'executor' folder to proceed."
}


# Function to configure environment variables
configure_environment() {
    process_message "Configuring environment variables"

    # NODE_ENV
    read -p "Enter Node Environment (e.g., testnet): " NODE_ENV
    export NODE_ENV=${NODE_ENV:-testnet}
    echo "export NODE_ENV=$NODE_ENV" >> "$HOME_DIR/.bashrc"

    # LOG LEVEL
    export LOG_LEVEL=debug
    echo "export LOG_LEVEL=debug" >> "$HOME_DIR/.bashrc"
    export LOG_PRETTY=false
    echo "export LOG_PRETTY=false" >> "$HOME_DIR/.bashrc"

    # PROCESS ORDERS AND CLAIMS
    export EXECUTOR_PROCESS_ORDERS=true
    echo "export EXECUTOR_PROCESS_ORDERS=true" >> "$HOME_DIR/.bashrc"
    export EXECUTOR_PROCESS_CLAIMS=true
    echo "export EXECUTOR_PROCESS_CLAIMS=true" >> "$HOME_DIR/.bashrc"

    # PRIVATE KEY
    read -p "Enter your PRIVATE_KEY_LOCAL: " PRIVATE_KEY_LOCAL
    export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
    echo "export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL" >> "$HOME_DIR/.bashrc"

    # NETWORKS
    read -p "Do you want to enable all networks? (Y/n): " ENABLE_ALL
    ENABLE_ALL=${ENABLE_ALL:-Y}
    ENABLED_NETWORKS=""
    if [[ $ENABLE_ALL =~ ^[Yy]$ ]]; then
        ENABLED_NETWORKS="arbitrum-sepolia,base-sepolia,blast-sepolia,optimism-sepolia,l1rn"
    else
        for NETWORK in "arbitrum-sepolia" "optimism-sepolia" "blast-sepolia" "base-sepolia"; do
            read -p "Will you enable the $NETWORK network? (Y/n): " ENABLE_NETWORK
            ENABLE_NETWORK=${ENABLE_NETWORK:-Y}
            if [[ $ENABLE_NETWORK =~ ^[Yy]$ ]]; then
                if [ -z "$ENABLED_NETWORKS" ]; then
                    ENABLED_NETWORKS="$NETWORK"
                else
                    ENABLED_NETWORKS="$ENABLED_NETWORKS,$NETWORK"
                fi
            fi
        done
    fi
    export ENABLED_NETWORKS
    echo "export ENABLED_NETWORKS='$ENABLED_NETWORKS'" >> "$HOME_DIR/.bashrc"

    # RPC ENDPOINTS
    read -p "Do you want to use the default RPC URLs? (Y/n): " USE_DEFAULT_RPC
    USE_DEFAULT_RPC=${USE_DEFAULT_RPC:-Y}
    if [[ ! $USE_DEFAULT_RPC =~ ^[Yy]$ ]]; then
        for NETWORK in "arbitrum-sepolia" "optimism-sepolia" "blast-sepolia" "base-sepolia"; do
            if [[ $ENABLED_NETWORKS == *"$NETWORK"* ]]; then
                read -p "Enter RPC URL for $NETWORK: " RPC_URL
                NETWORK_SHORT=$(echo $NETWORK | cut -d'-' -f1 | tr '[:lower:]' '[:upper:]')
                export RPC_ENDPOINTS_${NETWORK_SHORT}=$RPC_URL
                echo "export RPC_ENDPOINTS_${NETWORK_SHORT}='$RPC_URL'" >> "$HOME_DIR/.bashrc"
            fi
        done
    fi

    # PROCESS VIA API OR RPC
    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true
    echo "export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true" >> "$HOME_DIR/.bashrc"

    echo "Environment variables configured. Restart terminal or run 'source ~/.bashrc' to apply changes."
}

# Function to start Executor in the background
start_executor() {
    process_message "Starting Executor in the background"
    cd "$HOME_DIR/executor" || exit

    # Run the executor using nohup in the background
    nohup ./executor > executor.log 2>&1 &
    EXECUTOR_PID=$!
    echo "Executor started with PID $EXECUTOR_PID"
    echo "Logs are being written to $HOME_DIR"
    echo "Logs are being written to $HOME_DIR/executor/executor.log"
}

# Main function
main() {
    print_banner
    check_root
    download_executor
    configure_environment
    start_executor
    echo "Setup complete! The Executor is running in the background."
}

# Run the main function
main
