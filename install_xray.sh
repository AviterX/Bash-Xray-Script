#!/bin/bash

#================================================================================
#
#          FILE:  install_xray.sh
#
#   DESCRIPTION:  A comprehensive script to install and configure Xray-core
#                 on a Debian/Ubuntu VPS for VLESS-XTLS-Reality protocol.
#
#       VERSION:  2.1.0 (Fixed for newer Xray versions)
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
    if ! apt-get install -y curl socat wget unzip git openssl; then
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
    
    # Create a temporary file to capture the output
    local temp_file=$(mktemp)
    
    # Run xray x25519 command and capture output
    if ! "$XRAY_BINARY_PATH" x25519 > "$temp_file" 2>&1; then
        print_message "$RED" "Failed to execute xray x25519 command."
        rm -f "$temp_file"
        exit 1
    fi
    
    # Debug: Show the actual output
    print_message "$BLUE" "Xray x25519 output:"
    cat "$temp_file"
    
    # Parse the output - try multiple patterns for different Xray versions
    PRIVATE_KEY=$(grep -i "private" "$temp_file" | awk '{print $NF}' | head -1)
    PUBLIC_KEY=$(grep -i "public" "$temp_file" | awk '{print $NF}' | head -1)
    
    # Alternative parsing if the above doesn't work
    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        # Try parsing line by line
        while IFS= read -r line; do
            if [[ "$line" =~ [Pp]rivate.*key:?[[:space:]]*([A-Za-z0-9+/=_-]+) ]]; then
                PRIVATE_KEY="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ [Pp]ublic.*key:?[[:space:]]*([A-Za-z0-9+/=_-]+) ]]; then
                PUBLIC_KEY="${BASH_REMATCH[1]}"
            fi
        done < "$temp_file"
    fi
    
    # If still empty, try simpler extraction
    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        # Extract base64-like strings (common for keys)
        local keys=($(grep -oE '[A-Za-z0-9+/=_-]{40,}' "$temp_file"))
        if [[ ${#keys[@]} -ge 2 ]]; then
            PRIVATE_KEY="${keys[0]}"
            PUBLIC_KEY="${keys[1]}"
        fi
    fi
    
    # Clean up temp file
    rm -f "$temp_file"
    
    # Validate keys
    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        print_message "$RED" "Failed to generate Reality key pair. Please check Xray installation."
        print_message "$YELLOW" "You can manually generate keys with: $XRAY_BINARY_PATH x25519"
        exit 1
    fi
    
    print_message "$GREEN" "Reality key pair generated successfully."
    print_message "$BLUE" "Private Key: $PRIVATE_KEY"
    print_message "$BLUE" "Public Key: $PUBLIC_KEY"
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

    # Generate short ID (8 characters hex)
    SHORT_ID=$(openssl rand -hex 8)

    # Ensure config directory exists
    mkdir -p "$XRAY_INSTALL_DIR"

    # Create the config file with improved Reality settings
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
            "${SHORT_ID}",
            ""
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
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

    if [[ ! -f "$XRAY_CONFIG_FILE" ]]; then
        print_message "$RED" "Failed to create config file."
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 "$XRAY_CONFIG_FILE"
    
    print_message "$GREEN" "Xray configuration created successfully at ${XRAY_CONFIG_FILE}"
}

function display_connection_info() {
    local ip_address
    ip_address=$(curl -s https://api.ipify.org || curl -s https://ipinfo.io/ip || curl -s https://icanhazip.com)

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

    # Generate share link (URL encoded)
    local encoded_sni=$(printf '%s' "$SNI_DOMAIN" | sed 's/ /%20/g')
    local share_link="vless://${UUID}@${ip_address}:${LISTEN_PORT}?security=reality&sni=${encoded_sni}&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Xray_Reality"
    
    print_message "$BLUE" "Share Link (copy this into your client):"
    echo "${share_link}"
    echo ""
    
    # Save connection info to file
    cat > "/root/xray_connection_info.txt" << EOF
=== Xray Reality Connection Info ===
Protocol: VLESS
Address: ${ip_address}
Port: ${LISTEN_PORT}
UUID: ${UUID}
Flow: xtls-rprx-vision
Security: reality
SNI: ${SNI_DOMAIN}
Public Key: ${PUBLIC_KEY}
Short ID: ${SHORT_ID}
Fingerprint: ${FINGERPRINT}

Share Link:
${share_link}
EOF
    
    print_message "$GREEN" "Connection info saved to /root/xray_connection_info.txt"
}

function configure_firewall() {
    print_message "$BLUE" "Configuring firewall..."
    
    # Check if ufw is installed
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "$LISTEN_PORT"/tcp
        print_message "$GREEN" "Firewall configured for port $LISTEN_PORT"
    else
        print_message "$YELLOW" "UFW not found. Please manually open port $LISTEN_PORT in your firewall."
    fi
}

# --- Main Function ---
function main() {
    print_message "$GREEN" "Starting Xray Reality installation..."
    
    check_root
    update_system
    install_dependencies
    install_xray
    generate_keys
    get_user_input
    create_config
    configure_firewall

    print_message "$BLUE" "Restarting Xray service..."
    systemctl daemon-reload
    systemctl restart xray
    systemctl enable xray
    
    # Wait a moment for service to start
    sleep 3

    if systemctl is-active --quiet xray; then
        print_message "$GREEN" "Xray service is running successfully."
    else
        print_message "$RED" "Xray service failed to start. Checking logs..."
        journalctl -u xray --no-pager -n 20
        exit 1
    fi

    display_connection_info
    print_message "$GREEN" "Installation complete!"
    print_message "$YELLOW" "You can check service status with: systemctl status xray"
    print_message "$YELLOW" "View logs with: journalctl -u xray -f"
}

# --- Script Execution ---
main
