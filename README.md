# super-disco

![Banner](https://i.imgur.com/JQ7Z8lD.png)

A Telegram bot that remotely executes reconnaissance scans via SSH and delivers real-time results and reports.

## 🔥 Features

- **Remote SSH Command Execution** - Run commands on your scanning machine directly from Telegram
- **Automated Recon Scans** - Execute your recon.sh script with a single command
- **Real-time Progress Updates** - Get notifications as scans progress
- **Comprehensive Reporting** - Receive:
  - Complete scan logs
  - Markdown summary reports
  - Website screenshots
- **Secure Access** - Whitelisted users with Telegram authentication
- **Persistent Scans** - Runs in screen sessions that survive disconnections

## 🛠 Installation

### Prerequisites

1. Python 3.8+
2. SSH access to your scanning machine
3. Telegram account and bot token from [@BotFather](https://t.me/BotFather)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/recon-bot.git
   cd recon-bot
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configuration**
   Edit `config.py` with your details:
   ```python
   TELEGRAM_TOKEN = "YOUR_BOT_TOKEN"
   AUTHORIZED_USER_IDS = [123456789]  # Your Telegram user ID
   SSH_HOST = "your.scanning.server"
   SSH_PORT = 22
   SSH_USERNAME = "your_username"
   SSH_KEY_PATH = "/path/to/ssh_key"  # Or use password auth
   ```

4. **Deploy the bot**
   ```bash
   python3 telegram_recon_bot.py
   ```

## 🚀 Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `/start` | Show main menu |
| `/scan example.com` | Start recon scan for domain |
| `/status` | Check active scans |
| `/cmd "ls -la"` | Execute SSH command |

### Interactive Menu

1. Send `/start` to the bot
2. Choose from the menu:
   - **Run Recon Scan**: Start a new scan
   - **Check Active Scans**: View running scans
   - **SSH Command**: Execute custom commands

## 📂 File Structure

```
recon-bot/
├── telegram_recon_bot.py      # Main bot application
├── config.py                  # Configuration file
├── recon.sh                   # Enhanced recon script
├── requirements.txt           # Python dependencies
└── README.md                  # This file
```

## 🔒 Security

- Only whitelisted Telegram users can access the bot
- Uses SSH key authentication (recommended) or password
- No sensitive credentials stored in the bot
- All communication encrypted via Telegram's MTProto protocol

## 📈 Sample Workflow

1. User sends `/start` to bot
2. Selects "Run Recon Scan"
3. Enters target domain (example.com)
4. Bot:
   - Connects to SSH server
   - Starts scan in screen session
   - Sends periodic updates
5. Upon completion:
   - Sends log file
   - Sends markdown report
   - Sends screenshots

## 🤖 Advanced Features

- **Multiple simultaneous scans**
- **Custom command execution**
- **Progress tracking**
- **Automatic result delivery**
- **Persistent scan sessions**

## 🛑 Troubleshooting

**Issue**: Bot not responding
- Verify the bot is running (`ps aux | grep python`)
- Check Telegram API status

**Issue**: SSH connection fails
- Verify SSH keys are properly set up
- Check firewall rules

**Issue**: Scans not completing
- Check disk space on scanning machine
- Verify recon.sh has execute permissions

## 📜 License

MIT License - See [LICENSE](LICENSE) for details

## 👥 Contribution

Contributions welcome! Please open an issue or PR for any improvements.

---

**Happy Hunting!** 🎯
