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
    
    rm -rvf "$HOME_DIR/.zxc"  # Delete the .zxc profile file
    rm -rvf "$HOME_DIR/executor/"  # Delete the executor directory
    rm -rf "$HOME_DIR/executor-linux-*"  # Delete any old executor-linux files
    
    echo "Old data and binaries have been removed."
}

# Function to download the latest Executor binary
download_executor() {
    process_message "Downloading the latest Executor binary"
    
    # Fetch the latest release tag name from GitHub
    LATEST_TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | \
                 grep -Po '"tag_name": "\K.*?(?=")')
    if [ -z "$LATEST_TAG" ]; then
        echo "Failed to fetch the latest release. Exiting."
        exit 1
    fi

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
    if [ $? -ne 0 ]; then
        echo "Download failed. Exiting."
        exit 1
    fi

    process_message "Extracting Executor binary"
    tar -xzf "$HOME_DIR/$FILE_NAME" -C "$HOME_DIR"
    chmod +x "$HOME_DIR/executor/executor/bin/executor"
    echo "File extracted and permissions set. Navigate to the 'executor' folder to proceed."
}

# Function to configure environment variables
# Function to configure environment variables
configure_environment() {
    process_message "Configuring environment variables"

    ZXC_FILE="$HOME_DIR/.zxc"

    export NODE_ENV=testnet
    echo "export NODE_ENV=testnet" >> "$ZXC_FILE"

    export LOG_LEVEL=debug
    echo "export LOG_LEVEL=debug" >> "$ZXC_FILE"
    export LOG_PRETTY=false
    echo "export LOG_PRETTY=false" >> "$ZXC_FILE"

    export EXECUTOR_PROCESS_ORDERS=true
    echo "export EXECUTOR_PROCESS_ORDERS=true" >> "$ZXC_FILE"
    export EXECUTOR_PROCESS_CLAIMS=true
    echo "export EXECUTOR_PROCESS_CLAIMS=true" >> "$ZXC_FILE"

    read -p "Setup Your Gass Fee (example 100): " EXECUTOR_MAX_L3_GAS_PRICE
    export EXECUTOR_MAX_L3_GAS_PRICE=$EXECUTOR_MAX_L3_GAS_PRICE
    echo "export EXECUTOR_MAX_L3_GAS_PRICE=$EXECUTOR_MAX_L3_GAS_PRICE" >> "$ZXC_FILE"

    read -p "Enter your PRIVATE_KEY_LOCAL: " PRIVATE_KEY_LOCAL
    export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
    echo "export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL" >> "$ZXC_FILE"

    ENABLED_NETWORKS=""

    read -p "Do you want to enable arbitrum sepolia? (Y/n): " ENABLE_ARBITRUM
    while [[ ! $ENABLE_ARBITRUM =~ ^[YyNn]$ ]]; do
        echo "Invalid input. Please enter 'Y' or 'N'."
        read -p "Do you want to enable arbitrum sepolia? (Y/n): " ENABLE_ARBITRUM
    done
    if [[ $ENABLE_ARBITRUM =~ ^[Yy]$ ]]; then
        ENABLED_NETWORKS="arbitrum-sepolia"
        read -p "Do you want to use a custom RPC for arbitrum sepolia? (Y/n): " USE_CUSTOM_ARBITRUM_RPC
        while [[ ! $USE_CUSTOM_ARBITRUM_RPC =~ ^[YyNn]$ ]]; do
            echo "Invalid input. Please enter 'Y' or 'N'."
            read -p "Do you want to use a custom RPC for arbitrum sepolia? (Y/n): " USE_CUSTOM_ARBITRUM_RPC
        done
        if [[ $USE_CUSTOM_ARBITRUM_RPC =~ ^[Yy]$ ]]; then
            read -p "Enter your custom RPC URL for arbitrum sepolia: " CUSTOM_ARBITRUM_RPC
            export RPC_ENDPOINTS_ARBT=$CUSTOM_ARBITRUM_RPC
        else
            export RPC_ENDPOINTS_ARBT='https://endpoints.omniatech.io/v1/arbitrum/sepolia/public'
        fi
        echo "export RPC_ENDPOINTS_ARBT='$RPC_ENDPOINTS_ARBT'" >> "$ZXC_FILE"
    fi

    read -p "Do you want to enable base sepolia? (Y/n): " ENABLE_BASE
    while [[ ! $ENABLE_BASE =~ ^[YyNn]$ ]]; do
        echo "Invalid input. Please enter 'Y' or 'N'."
        read -p "Do you want to enable base sepolia? (Y/n): " ENABLE_BASE
    done
    if [[ $ENABLE_BASE =~ ^[Yy]$ ]]; then
        ENABLED_NETWORKS+="${ENABLED_NETWORKS:+,}base-sepolia"
        read -p "Do you want to use a custom RPC for base sepolia? (Y/n): " USE_CUSTOM_BASE_RPC
        while [[ ! $USE_CUSTOM_BASE_RPC =~ ^[YyNn]$ ]]; do
            echo "Invalid input. Please enter 'Y' or 'N'."
            read -p "Do you want to use a custom RPC for base sepolia? (Y/n): " USE_CUSTOM_BASE_RPC
        done
        if [[ $USE_CUSTOM_BASE_RPC =~ ^[Yy]$ ]]; then
            read -p "Enter your custom RPC URL for base sepolia: " CUSTOM_BASE_RPC
            export RPC_ENDPOINTS_BSSP=$CUSTOM_BASE_RPC
        else
            export RPC_ENDPOINTS_BSSP='https://sepolia.base.org'
        fi
        echo "export RPC_ENDPOINTS_BSSP='$RPC_ENDPOINTS_BSSP'" >> "$ZXC_FILE"
    fi

    read -p "Do you want to enable op sepolia? (Y/n): " ENABLE_OP
    while [[ ! $ENABLE_OP =~ ^[YyNn]$ ]]; do
        echo "Invalid input. Please enter 'Y' or 'N'."
        read -p "Do you want to enable op sepolia? (Y/n): " ENABLE_OP
    done
    if [[ $ENABLE_OP =~ ^[Yy]$ ]]; then
        ENABLED_NETWORKS+="${ENABLED_NETWORKS:+,}optimism-sepolia"
        read -p "Do you want to use a custom RPC for op sepolia? (Y/n): " USE_CUSTOM_OP_RPC
        while [[ ! $USE_CUSTOM_OP_RPC =~ ^[YyNn]$ ]]; do
            echo "Invalid input. Please enter 'Y' or 'N'."
            read -p "Do you want to use a custom RPC for op sepolia? (Y/n): " USE_CUSTOM_OP_RPC
        done
        if [[ $USE_CUSTOM_OP_RPC =~ ^[Yy]$ ]]; then
            read -p "Enter your custom RPC URL for op sepolia: " CUSTOM_OP_RPC
            export RPC_ENDPOINTS_OPSP=$CUSTOM_OP_RPC
        else
            export RPC_ENDPOINTS_OPSP='https://endpoints.omniatech.io/v1/op/sepolia/public'
        fi
        echo "export RPC_ENDPOINTS_OPSP='$RPC_ENDPOINTS_OPSP'" >> "$ZXC_FILE"
    fi

    read -p "Do you want to enable blast sepolia? (Y/n): " ENABLE_BLAST
    while [[ ! $ENABLE_BLAST =~ ^[YyNn]$ ]]; do
        echo "Invalid input. Please enter 'Y' or 'N'."
        read -p "Do you want to enable blast sepolia? (Y/n): " ENABLE_BLAST
    done
    if [[ $ENABLE_BLAST =~ ^[Yy]$ ]]; then
        ENABLED_NETWORKS+="${ENABLED_NETWORKS:+,}blast-sepolia"
        read -p "Do you want to use a custom RPC for blast sepolia? (Y/n): " USE_CUSTOM_BLAST_RPC
        while [[ ! $USE_CUSTOM_BLAST_RPC =~ ^[YyNn]$ ]]; do
            echo "Invalid input. Please enter 'Y' or 'N'."
            read -p "Do you want to use a custom RPC for blast sepolia? (Y/n): " USE_CUSTOM_BLAST_RPC
        done
        if [[ $USE_CUSTOM_BLAST_RPC =~ ^[Yy]$ ]]; then
            read -p "Enter your custom RPC URL for blast sepolia: " CUSTOM_BLAST_RPC
            export RPC_ENDPOINTS_BLSS=$CUSTOM_BLAST_RPC
        else
            export RPC_ENDPOINTS_BLSS='https://endpoints.omniatech.io/v1/blast/sepolia/public'
        fi
        echo "export RPC_ENDPOINTS_BLSS='$RPC_ENDPOINTS_BLSS'" >> "$ZXC_FILE"
    fi

    # Always enable l1rn
    ENABLED_NETWORKS+="${ENABLED_NETWORKS:+,}l1rn"
    export RPC_ENDPOINTS_L1RN='https://brn.rpc.caldera.xyz/'
    echo "export RPC_ENDPOINTS_L1RN='https://brn.rpc.caldera.xyz/'" >> "$ZXC_FILE"

    export ENABLED_NETWORKS
    echo "export ENABLED_NETWORKS='$ENABLED_NETWORKS'" >> "$ZXC_FILE"

    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true
    echo "export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true" >> "$ZXC_FILE"

    source "$ZXC_FILE"
    echo "Environment variables configured. To apply changes, run 'source ~/.zxc' or restart your terminal."
}


# Function to start Executor in the background
start_executor() {
    process_message "Starting Executor in the background"
    cd "$HOME_DIR/executor/executor/bin" || exit
    nohup ./executor > "$HOME_DIR/executor/executor.log" 2>&1 &
    EXECUTOR_PID=$!
    echo "Executor started with PID $EXECUTOR_PID"
    echo "Logs are being written to $HOME_DIR/executor/executor.log"
    echo "Check Log: tail -f $HOME_DIR/executor/executor.log"
    echo "Check Status: $HOME_DIR/t3rn-executor/cek-status.sh"
    echo "Stop Executor: $HOME_DIR/t3rn-executor/stop-executor.sh"
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
