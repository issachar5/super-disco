#!/usr/bin/env python3
import os
import paramiko
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext, CallbackQueryHandler
import logging
import time
import subprocess
from io import BytesIO

# Configuration
TELEGRAM_TOKEN = "YOUR_TELEGRAM_BOT_TOKEN"
AUTHORIZED_USER_IDS = [YOUR_TELEGRAM_USER_ID]  # Add your Telegram user ID
SSH_HOST = "your_ssh_host"
SSH_PORT = 22
SSH_USERNAME = "your_ssh_username"
SSH_KEY_PATH = "/path/to/your/ssh_key"  # or use password

# Setup logging
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

class SSHBot:
    def __init__(self):
        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.current_directory = "~"
        self.active_scans = {}

    def connect(self):
        try:
            self.ssh.connect(SSH_HOST, port=SSH_PORT, username=SSH_USERNAME, key_filename=SSH_KEY_PATH)
            return True
        except Exception as e:
            logger.error(f"SSH Connection failed: {e}")
            return False

    def execute_command(self, command):
        try:
            stdin, stdout, stderr = self.ssh.exec_command(f"cd {self.current_directory} && {command}")
            output = stdout.read().decode()
            error = stderr.read().decode()
            return output, error
        except Exception as e:
            return None, str(e)

    def start_recon_scan(self, target, chat_id):
        scan_id = str(int(time.time()))
        self.active_scans[scan_id] = {
            'target': target,
            'chat_id': chat_id,
            'status': 'running',
            'start_time': time.time()
        }

        # Start the scan in a screen session so it persists
        command = f"screen -dmS recon_{scan_id} bash -c 'cd ~/recon-scripts && ./recon.sh -d {target}; echo \"SCAN_COMPLETE\"'"
        output, error = self.execute_command(command)

        if error:
            return False, error
        return True, scan_id

    def check_scan_progress(self, scan_id):
        # Check if the screen session still exists
        output, error = self.execute_command(f"screen -list | grep recon_{scan_id}")

        if "SCAN_COMPLETE" in output:
            return "complete"
        elif output:
            return "running"
        else:
            return "failed"

    def get_scan_results(self, scan_id):
        # Get the latest log file
        target = self.active_scans[scan_id]['target']
        log_file = f"~/recon/{target}/scan.log"

        # Get the report
        report_file = f"~/recon/{target}/report.md"

        # Get screenshots directory
        screenshots_dir = f"~/recon/{target}/screenshots/aquatone_screenshots/"

        return log_file, report_file, screenshots_dir

def start(update: Update, context: CallbackContext) -> None:
    if update.effective_user.id not in AUTHORIZED_USER_IDS:
        update.message.reply_text("🚫 Unauthorized access denied.")
        return

    keyboard = [
        [InlineKeyboardButton("Run Recon Scan", callback_data='run_recon')],
        [InlineKeyboardButton("Check Active Scans", callback_data='check_scans')],
        [InlineKeyboardButton("SSH Command", callback_data='ssh_cmd')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    update.message.reply_text('🛠 SSH Recon Bot Menu:', reply_markup=reply_markup)

def button_handler(update: Update, context: CallbackContext) -> None:
    query = update.callback_query
    query.answer()

    if query.data == 'run_recon':
        query.edit_message_text(text="Please send the target domain (e.g., example.com)")
        context.user_data['awaiting_target'] = True
    elif query.data == 'check_scans':
        list_active_scans(update, context)
    elif query.data == 'ssh_cmd':
        query.edit_message_text(text="Please send the SSH command to execute")
        context.user_data['awaiting_ssh_cmd'] = True

def handle_message(update: Update, context: CallbackContext) -> None:
    if update.effective_user.id not in AUTHORIZED_USER_IDS:
        return

    if context.user_data.get('awaiting_target'):
        target = update.message.text
        context.user_data['awaiting_target'] = False

        ssh_bot = SSHBot()
        if not ssh_bot.connect():
            update.message.reply_text("🔴 Failed to connect to SSH server")
            return

        success, scan_id_or_error = ssh_bot.start_recon_scan(target, update.message.chat_id)

        if success:
            context.user_data['active_scan_id'] = scan_id_or_error
            update.message.reply_text(f"🟢 Started recon scan for {target}\nScan ID: {scan_id_or_error}")

            # Start progress updates
            context.job_queue.run_repeating(update_scan_progress, interval=60, first=10,
                                          context={'chat_id': update.message.chat_id, 'scan_id': scan_id_or_error})
        else:
            update.message.reply_text(f"🔴 Failed to start scan: {scan_id_or_error}")

    elif context.user_data.get('awaiting_ssh_cmd'):
        command = update.message.text
        context.user_data['awaiting_ssh_cmd'] = False

        ssh_bot = SSHBot()
        if not ssh_bot.connect():
            update.message.reply_text("🔴 Failed to connect to SSH server")
            return

        output, error = ssh_bot.execute_command(command)

        response = "⚙️ Command Results:\n"
        if output:
            response += f"<code>{output[:4000]}</code>\n"  # Truncate to avoid message limits
        if error:
            response += f"\n❌ Errors:\n<code>{error[:2000]}</code>"

        update.message.reply_text(response, parse_mode='HTML')

def update_scan_progress(context: CallbackContext):
    job = context.job
    scan_id = job.context['scan_id']
    chat_id = job.context['chat_id']

    ssh_bot = SSHBot()
    if not ssh_bot.connect():
        context.bot.send_message(chat_id, "🔴 Lost connection to SSH server")
        return

    status = ssh_bot.check_scan_progress(scan_id)

    if status == "complete":
        context.bot.send_message(chat_id, f"✅ Scan {scan_id} completed!")

        # Get and send results
        log_file, report_file, screenshots_dir = ssh_bot.get_scan_results(scan_id)

        # Send log file
        stdin, stdout, stderr = ssh_bot.ssh.exec_command(f"cat {log_file}")
        log_content = stdout.read().decode()
        context.bot.send_document(chat_id, document=BytesIO(log_content.encode()), filename=f"scan_{scan_id}.log")

        # Send report
        stdin, stdout, stderr = ssh_bot.ssh.exec_command(f"cat {report_file}")
        report_content = stdout.read().decode()
        context.bot.send_document(chat_id, document=BytesIO(report_content.encode()), filename=f"report_{scan_id}.md")

        # Send screenshots (first 10)
        stdin, stdout, stderr = ssh_bot.ssh.exec_command(f"ls {screenshots_dir} | head -10")
        screenshot_files = stdout.read().decode().splitlines()

        for screenshot in screenshot_files:
            sftp = ssh_bot.ssh.open_sftp()
            remote_file = sftp.file(f"{screenshots_dir}/{screenshot}", 'r')
            context.bot.send_photo(chat_id, photo=remote_file)
            remote_file.close()

        job.schedule_removal()
    elif status == "failed":
        context.bot.send_message(chat_id, f"🔴 Scan {scan_id} failed!")
        job.schedule_removal()
    else:
        context.bot.send_message(chat_id, f"🔄 Scan {scan_id} still running...")

def list_active_scans(update: Update, context: CallbackContext):
    ssh_bot = SSHBot()
    if not ssh_bot.connect():
        update.callback_query.edit_message_text("🔴 Failed to connect to SSH server")
        return

    output, error = ssh_bot.execute_command("screen -list")

    if "No Sockets found" in output:
        update.callback_query.edit_message_text("No active scans running")
    else:
        update.callback_query.edit_message_text(f"Active scans:\n<code>{output}</code>", parse_mode='HTML')

def error_handler(update: Update, context: CallbackContext) -> None:
    logger.error(msg="Exception while handling update:", exc_info=context.error)
    if update and update.effective_message:
        update.effective_message.reply_text('⚠️ An error occurred. Please try again.')

def main() -> None:
    updater = Updater(TELEGRAM_TOKEN)
    dispatcher = updater.dispatcher

    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CallbackQueryHandler(button_handler))
    dispatcher.add_handler(MessageHandler(Filters.text & ~Filters.command, handle_message))
    dispatcher.add_error_handler(error_handler)

    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
