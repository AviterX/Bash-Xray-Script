# Xray Installation Script

Automated installation and configuration of Xray-core with VLESS-XTLS-Reality protocol for Debian/Ubuntu systems.

## Features

- One-command installation with latest Xray-core
- VLESS-XTLS-Reality protocol with traffic camouflage
- Automatic key generation and configuration
- Client-ready share URLs
- Systemd service integration

## Installation

```bash
sudo -s
```
```bash
wget -O install_xray.sh "https://raw.githubusercontent.com/AviterX/Bash-Xray-Script/main/install_xray.sh"
```
```bash
chmod +x install_xray.sh && ./install_xray.sh
```

## Configuration

You'll be prompted for:
- **UUID**: [UUID Generator](https://www.uuidgenerator.net/)
- **Port**: Default 443
- **SNI Domain**: Use popular domains like `zoom.us`

## Management

```bash
# Service control
systemctl status|start|stop|restart xray

# View logs
journalctl -u xray -f

# Connection info
cat /root/xray_connection_info.txt
```

## Client Compatibility

- v2rayN (Windows)
- Nekoray (Cross-platform)
- Netmod (Windows)
- v2rayNG (Android)
- FoXray (iOS)

## File Locations

- Config: `/usr/local/etc/xray/config.json`
- Binary: `/usr/local/bin/xray`
- Connection info: `/root/xray_connection_info.txt`

## Troubleshooting

```bash
# Check service logs
journalctl -u xray --no-pager -n 20

# Test configuration
/usr/local/bin/xray -test -config /usr/local/etc/xray/config.json
```

## License

MIT License - Use responsibly and comply with local laws.

---
## Disclaimer

This software is provided for educational purposes. Users are responsible for compliance with local laws and regulations. The authors assume no liability for misuse or legal violations.

---

⭐ **Star this repo if helpful!**
