#!/bin/bash

#================================================================================
#
#          FILE:  install_xray.sh
#
#   DESCRIPTION:  A comprehensive script to install and configure Xray-core
#                 on a Debian/Ubuntu VPS for VLESS-XTLS-Reality protocol.
#
#       VERSION:  2.0.0
#        AUTHOR:  Team AviterX
#
#================================================================================

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Global Variables ---
XRAY_INSTALL_DIR="/usr/local/etc/xray"
XRAY_CONFIG_FILE="${XRAY_INSTALL_DIR}/config.json"
XRAY_BINARY_PATH="/usr/local/bin/xray"
SERVICE_FILE_PATH="/etc/systemd/system/xray.service"

# --- Helper Functions ---
function print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

function check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_message "$RED" "This script must be run as root. Please use 'sudo' or run as the root user."
        exit 1
    fi
}

function update_system() {
    print_message "$BLUE" "Updating system packages..."
    if ! apt-get update && apt-get upgrade -y; then
        print_message "$RED" "Failed to update system packages. Please check your network connection and repositories."
        exit 1
    fi
    print_message "$GREEN" "System packages updated successfully."
}

function install_dependencies() {
    print_message "$BLUE" "Installing necessary dependencies..."
    if ! apt-get install -y curl socat wget unzip git; then
        print_message "$RED" "Failed to install dependencies."
        exit 1
    fi
    print_message "$GREEN" "Dependencies installed successfully."
}

function install_xray() {
    print_message "$BLUE" "Installing Xray-core..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    if [[ ! -f "$XRAY_BINARY_PATH" ]]; then
        print_message "$RED" "Xray installation failed."
        exit 1
    fi
    print_message "$GREEN" "Xray-core installed successfully."
}

function generate_keys() {
    print_message "$BLUE" "Generating Reality key pair..."
    local key_pair
    key_pair=$($XRAY_BINARY_PATH x25519)
    PRIVATE_KEY=$(echo "$key_pair" | awk '/Private key/ {print $3}')
    PUBLIC_KEY=$(echo "$key_pair" | awk '/Public key/ {print $3}')
    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        print_message "$RED" "Failed to generate Reality key pair."
        exit 1
    fi
    print_message "$GREEN" "Reality key pair generated."
}

function get_user_input() {
    print_message "$YELLOW" "Please provide the following information:"
    read -rp "Enter a UUID (or press Enter to generate one): " UUID
    if [[ -z "$UUID" ]]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
        print_message "$GREEN" "Generated UUID: $UUID"
    fi

    read -rp "Enter the listening port for Xray (default: 443): " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-443}

    read -rp "Enter the domain to use for SNI (e.g., www.microsoft.com): " SNI_DOMAIN
    if [[ -z "$SNI_DOMAIN" ]]; then
        print_message "$RED" "SNI domain cannot be empty."
        exit 1
    fi
}

function create_config() {
    print_message "$BLUE" "Creating Xray configuration file..."

    # Generate short ID
    SHORT_ID=$(openssl rand -hex 8)

    # Create the config file
    cat > "$XRAY_CONFIG_FILE" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${LISTEN_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI_DOMAIN}:443",
          "xver": 0,
          "serverNames": [
            "${SNI_DOMAIN}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

    if [[ ! -f "$XRAY_CONFIG_FILE" ]]; then
        print_message "$RED" "Failed to create config file."
        exit 1
    fi
    print_message "$GREEN" "Xray configuration created successfully at ${XRAY_CONFIG_FILE}"
}

function display_connection_info() {
    local ip_address
    ip_address=$(curl -s https://api.ipify.org)

    print_message "$YELLOW" "--- AviterX1Pro Xray Script ---"
    print_message "$GREEN" "Protocol: VLESS"
    print_message "$GREEN" "Address: ${ip_address}"
    print_message "$GREEN" "Port: ${LISTEN_PORT}"
    print_message "$GREEN" "UUID: ${UUID}"
    print_message "$GREEN" "Flow: xtls-rprx-vision"
    print_message "$GREEN" "Security: reality"
    print_message "$GREEN" "SNI: ${SNI_DOMAIN}"
    print_message "$GREEN" "Public Key: ${PUBLIC_KEY}"
    print_message "$GREEN" "Short ID: ${SHORT_ID}"
    print_message "$YELLOW" "---------------------------------"

    # Generate share link
    local share_link="vless://${UUID}@${ip_address}:${LISTEN_PORT}?security=reality&sni=${SNI_DOMAIN}&flow=xtls-rprx-vision&publicKey=${PUBLIC_KEY}&shortId=${SHORT_ID}#Xray_Reality"
    print_message "$BLUE" "Share Link (copy this into your client):"
    echo "${share_link}"
}


# --- Main Function ---
function main() {
    check_root
    update_system
    install_dependencies
    install_xray
    generate_keys
    get_user_input
    create_config

    print_message "$BLUE" "Restarting Xray service..."
    systemctl restart xray
    systemctl enable xray

    if systemctl is-active --quiet xray; then
        print_message "$GREEN" "Xray service is running."
    else
        print_message "$RED" "Xray service failed to start. Check logs with 'journalctl -u xray'."
        exit 1
    fi

    display_connection_info
    print_message "$GREEN" "Installation complete!"
}

# --- Script Execution ---
main
