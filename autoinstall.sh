#!/bin/bash

print_banner() {
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    echo -e "\e[44mWelcome to the t3rn Executor Setup!\e[0m"
}

process_message() {
    echo -e "\n\e[42m$1...\e[0m\n" && sleep 1
}

check_root() {
    process_message "Checking root privileges"
    if [ "$EUID" -ne 0 ]; then
        HOME_DIR="/home/$USER"
    else
        HOME_DIR="/root"
    fi
    mkdir -p "$HOME_DIR/t3rn"
}

install_dependencies() {
    process_message "Installing Node.js v22.14.0"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
    node -v
}

download_executor() {
    process_message "Downloading latest Executor binary"
    cd "$HOME_DIR/t3rn"
    LATEST_TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    OS_TYPE=$(uname -s)

    if [ "$OS_TYPE" == "Linux" ]; then
        FILE_NAME="executor-linux-$LATEST_TAG.tar.gz"
    elif [ "$OS_TYPE" == "Darwin" ]; then
        FILE_NAME="executor-macos-$LATEST_TAG.tar.gz"
    else
        echo "Unsupported OS"
        exit 1
    fi

    wget -q https://github.com/t3rn/executor-release/releases/download/$LATEST_TAG/$FILE_NAME
    tar -xzf $FILE_NAME
    chmod +x executor/executor/bin/executor
}

configure_environment() {
    process_message "Configuring environment variables"
    cp $HOME_DIR/.bashrc $HOME_DIR/.zxc
    ZXC_FILE="$HOME_DIR/.zxc"

    echo "export ENVIRONMENT=testnet" > "$ZXC_FILE"
    echo "export LOG_LEVEL=debug" >> "$ZXC_FILE"
    echo "export LOG_PRETTY=false" >> "$ZXC_FILE"
    echo "export EXECUTOR_PROCESS_BIDS_ENABLED=true" >> "$ZXC_FILE"
    echo "export EXECUTOR_PROCESS_ORDERS_ENABLED=true" >> "$ZXC_FILE"
    echo "export EXECUTOR_PROCESS_CLAIMS_ENABLED=true" >> "$ZXC_FILE"
    echo "export EXECUTOR_MAX_L3_GAS_PRICE=100" >> "$ZXC_FILE"

    read -p "Enter your PRIVATE_KEY_LOCAL: " PRIVATE_KEY_LOCAL
    echo "export PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL" >> "$ZXC_FILE"

    echo "export ENABLED_NETWORKS='arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn'" >> "$ZXC_FILE"

    read -p "Do you want to use a custom RPC? (Y/n): " USE_CUSTOM_RPC
    if [[ $USE_CUSTOM_RPC =~ ^[Yy]$ ]]; then
        read -p "Enter your custom RPC JSON: " CUSTOM_RPC
        echo "export RPC_ENDPOINTS='$CUSTOM_RPC'" >> "$ZXC_FILE"
    else
        DEFAULT_RPC='{
"l2rn": ["https://b2n.rpc.caldera.xyz/http"],
"arbt": ["https://arbitrum-sepolia.drpc.org", "https://sepolia-rollup.arbitrum.io/rpc"],
"bast": ["https://base-sepolia-rpc.publicnode.com", "https://base-sepolia.drpc.org"],
"opst": ["https://sepolia.optimism.io", "https://optimism-sepolia.drpc.org"]
}'
        echo "export RPC_ENDPOINTS='$DEFAULT_RPC'" >> "$ZXC_FILE"
    fi

    echo "export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true" >> "$ZXC_FILE"
    source $HOME_DIR/.zxc
}

create_systemd_service() {
    process_message "Creating systemd service"
    SERVICE_FILE="/etc/systemd/system/t3rn-executor.service"

    cat <<EOF | sudo tee $SERVICE_FILE
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
Type=simple
EnvironmentFile=$HOME_DIR/t3rn/.executor_env
WorkingDirectory=$HOME_DIR/t3rn/executor/executor/bin
ExecStart=$HOME_DIR/t3rn/executor/executor/bin/executor
Restart=always
StandardOutput=append:$HOME_DIR/t3rn/executor.log
StandardError=append:$HOME_DIR/t3rn/executor.log

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable t3rn-executor
    sudo systemctl start t3rn-executor
}

start_service() {
    process_message "Starting t3rn-executor service"
    sudo systemctl start t3rn-executor
}

stop_service() {
    process_message "Stopping t3rn-executor service"
    sudo systemctl stop t3rn-executor
}

uninstall_executor() {
    process_message "Uninstalling Executor and removing systemd service"
    sudo systemctl stop t3rn-executor
    sudo systemctl disable t3rn-executor
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload
    rm -rf "$HOME_DIR/t3rn"
    rm -f "$HOME_DIR/.zxc"
    source $HOME_DIR/.bashrc
    echo "Executor uninstalled."
}

menu() {
    print_banner
    check_root

    PS3="Select an option: "
    options=(
        "Install Dependencies (Node.js v22.14.0)"
        "Download & Install Executor"
        "Configure Environment"
        "Create Systemd Service & Start"
        "View Logs"
        "Start Service"
        "Stop Service"
        "Uninstall Executor"
        "Exit"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1)install_dependencies;;
            2)download_executor;;
            3)configure_environment;;
            4)create_systemd_service;;
            5)tail -f "$HOME_DIR/t3rn/executor.log";;
            6)start_service;;
            7)stop_service;;
            8)uninstall_executor;;
            9)break;;
            *)echo "Invalid option";;
        esac
    done
}

menu
