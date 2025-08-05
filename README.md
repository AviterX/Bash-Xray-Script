# 🚀 Bash-Xray-Install

A modern, automated bash script to easily install and configure **Xray-core** on your Debian or Ubuntu-based VPS. This script sets up a secure VLESS proxy in minutes! 💻🔐

---

## 📌 Features

✅ One-liner installation\
✅ Automatically downloads and installs latest Xray-core\
✅ Configures secure VLESS protocol with TLS\
✅ Enables and starts the Xray systemd service\
✅ Easy management with systemctl\
✅ Lightweight, clean, and fast setup

---

## ⚙️ Installation

Run the following commands **one by one** in your terminal:

```bash
sudo -s
```

```bash
wget -O install_xray.sh "https://raw.githubusercontent.com/AviterX/Bash-Xray-Script/refs/heads/main/install_xray.sh"
```

```bash
chmod +x install_xray.sh
```

```bash
./install_xray.sh
```

📎 **Note:** You will need to generate a UUID manually. 👉 Get your UUID from [uuidgenerator.net](https://www.uuidgenerator.net/)

---

## 🛠️ Managing Your Xray Service

Use the following `systemctl` commands to manage Xray on your VPS:

🔍 Check service status:

```bash
systemctl status xray
```

⛔ Stop the service:

```bash
systemctl stop xray
```

▶️ Start the service:

```bash
systemctl start xray
```

🔄 Restart the service:

```bash
systemctl restart xray
```

📜 View real-time logs:

```bash
journalctl -u xray -f
```

## 🙋‍♂️ Author

Made with ❤️ by [Team AviterX](https://github.com/AviterX)

## ☕ Support / Contributions

If you find this helpful, give it a ⭐ on GitHub! Contributions and suggestions are welcome.

## 🔐 Disclaimer

Use this script responsibly. Ensure your usage complies with your country's laws and your server provider's terms of service.
