#!/bin/bash

# Function to print the banner
print_banner() {
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
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

# Function to delete old data
delete_old_data() {
    process_message "Deleting Old Data + Old Binary"
    
    # Ensure the correct file and directory paths are used
    rm -rvf "$HOME_DIR/.zxc"  # Delete the .zxc profile file
    rm -rvf "$HOME_DIR/executor/"  # Delete the executor directory
    rm -rf "$HOME_DIR/executor-linux-*"  # Delete any old executor-linux files
    
    echo "Old data and binaries have been removed."
}

# Function to download the latest Executor binary (specific version)
download_executor() {
    process_message "Downloading the Executor binary (v0.31.0)"
    # Determine the OS type
    OS_TYPE=$(uname -s)
    if [ "$OS_TYPE" == "Linux" ]; then
        FILE_NAME="executor-linux-v0.34.0.tar.gz"
    elif [ "$OS_TYPE" == "Darwin" ]; then
        FILE_NAME="executor-macosx-v0.34.0.tar.gz"
    else
        echo "Unsupported OS: $OS_TYPE"
        exit 1
    fi
    DOWNLOAD_URL="https://github.com/t3rn/executor-release/releases/download/v0.34.0/$FILE_NAME"
    curl -L $DOWNLOAD_URL -o "$HOME_DIR/$FILE_NAME"
    process_message "Extracting Executor binary"
    tar -xzf "$HOME_DIR/$FILE_NAME" -C "$HOME_DIR"
    # Grant execute permissions to the executor binary
    chmod +x "$HOME_DIR/executor/executor/bin/executor"
    echo "File extracted and permissions set. Navigate to the 'executor' folder to proceed."
}

# Function to configure environment variables
configure_environment() {
    process_message "Configuring environment variables"

    # Define the path to the .zxc file
    ZXC_FILE="$HOME_DIR/.zxc"

    # NODE_ENV
    export NODE_ENV=testnet
    echo "export NODE_ENV=testnet" >> "$ZXC_FILE"

    # LOG LEVEL
    export LOG_LEVEL=debug
    echo "export LOG_LEVEL=debug" >> "$ZXC_FILE"
    export LOG_PRETTY=false
    echo "export LOG_PRETTY=false" >> "$ZXC_FILE"

    # PROCESS ORDERS AND CLAIMS
    export EXECUTOR_PROCESS_ORDERS=true
    echo "export EXECUTOR_PROCESS_ORDERS=true" >> "$ZXC_FILE"
    export EXECUTOR_PROCESS_CLAIMS=true
    echo "export EXECUTOR_PROCESS_CLAIMS=true" >> "$ZXC_FILE"

    # GASS FEE
    read -p "Setup Your Gass Fee (example 100) : " EXECUTOR_MAX_L3_GAS_PRICE
    export EXECUTOR_MAX_L3_GAS_PRICE=$EXECUTOR_MAX_L3_GAS_PRICE
    echo "export EXECUTOR_MAX_L3_GAS_PRICE=$EXECUTOR_MAX_L3_GAS_PRICE" >> "$ZXC_FILE"

    # PRIVATE KEY
    read -p "Enter your PRIVATE_KEY_LOCAL: " PRIVATE_KEY_LOCAL
    export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
    echo "export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL" >> "$ZXC_FILE"

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
    echo "export ENABLED_NETWORKS='$ENABLED_NETWORKS'" >> "$ZXC_FILE"

    # RPC ENDPOINTS
    read -p "Do you want to use the default RPC URLs? (Y/n): " USE_DEFAULT_RPC
    USE_DEFAULT_RPC=${USE_DEFAULT_RPC:-Y}
    if [[ ! $USE_DEFAULT_RPC =~ ^[Yy]$ ]]; then
        for NETWORK in "arbitrum-sepolia" "optimism-sepolia" "blast-sepolia" "base-sepolia"; do
            if [[ $ENABLED_NETWORKS == *"$NETWORK"* ]]; then
                read -p "Enter RPC URL for $NETWORK: " RPC_URL
                NETWORK_SHORT=$(echo $NETWORK | cut -d'-' -f1 | tr '[:lower:]' '[:upper:]')
                export RPC_ENDPOINTS_${NETWORK_SHORT}=$RPC_URL
                echo "export RPC_ENDPOINTS_${NETWORK_SHORT}='$RPC_URL'" >> "$ZXC_FILE"
            fi
        done
    fi

    # PROCESS VIA API OR RPC
    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true
    echo "export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true" >> "$ZXC_FILE"
    source ~/.zxc
    echo "Environment variables configured. To apply changes, run 'source ~/.zxc' or restart your terminal."
}

# Function to start Executor in the background
start_executor() {
    process_message "Starting Executor in the background"
    cd "$HOME_DIR/executor/executor/bin" || exit

    # Run the executor using nohup in the background
    nohup ./executor > $HOME_DIR/executor/executor.log 2>&1 &
    EXECUTOR_PID=$!
    echo "Executor started with PID $EXECUTOR_PID"
    echo "Logs are being written to $HOME_DIR/executor/executor.log"
    echo "Check Log tail -f $HOME_DIR/executor/executor.log"
    echo "Check Status Executor $HOME_DIR/t3rn-executor/cek-status.sh"
    echo "Stop Executor $HOME_DIR/t3rn-executor/stop-executor.sh"
}

# Main function
main() {
    print_banner
    check_root
    delete_old_data
    download_executor
    configure_environment
    start_executor
    echo "Setup complete! The Executor is running in the background."
}

# Run the main function
main
