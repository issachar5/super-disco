#!/bin/bash

# === Enhanced Config ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TARGET=""
OUTPUT_DIR="recon"
WORDLIST="/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt"
THREADS=20
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
TOOLS=(subfinder amass httpx whatweb ffuf gau waybackurls hakrawler arjun nmap nuclei gospider dnsx metabigor github-subdomains shosubgo aquatone naabu)

# === Enhanced Functions ===
print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo " ██▓ ███▄ ▄███▓ ██▓███   ▄████▄   ██▓     ██▓ ███▄    █  ▄▄▄     ▄▄▄█████▓"
    echo "▓██▒▓██▒▀█▀ ██▒▓██░  ██▒▒██▀ ▀█  ▓██▒    ▓██▒ ██ ▀█   █ ▒████▄   ▓  ██▒ ▓▒"
    echo "▒██▒▓██    ▓██░▓██░ ██▓▒▒▓█    ▄ ▒██░    ▒██▒▓██  ▀█ ██▒▒██  ▀█▄ ▒ ▓██░ ▒░"
    echo "░██░▒██    ▒██ ▒██▄█▓▒ ▒▒▓▓▄ ▄██▒▒██░    ░██░▓██▒  ▐▌██▒░██▄▄▄▄██░ ▓██▓ ░ "
    echo "░██░▒██▒   ░██▒▒██▒ ░  ░▒ ▓███▀ ░░██████▒░██░▒██░   ▓██░ ▓█   ▓██▒ ▒██▒ ░ "
    echo "░▓  ░ ▒░   ░  ░▒▓▒░ ░  ░░ ░▒ ▒  ░░ ▒░▓  ░░▓  ░ ▒░   ▒ ▒  ▒▒   ▓▒█░ ▒ ░░   "
    echo " ▒ ░░  ░      ░░▒ ░       ░  ▒   ░ ░ ▒  ░ ▒ ░░ ░░   ░ ▒░  ▒   ▒▒ ░   ░    "
    echo " ▒ ░░      ░   ░░       ░          ░ ░    ▒ ░   ░   ░ ░   ░   ▒    ░      "
    echo " ░         ░            ░ ░          ░  ░ ░           ░       ░  ░        "
    echo "                         ░                                                  "
    echo -e "${CYAN}"
    echo "                     ÏSSACHAR'S RECON MASTER v2.0"
    echo "                  Next-Generation Reconnaissance Suite"
    echo -e "${NC}"
    echo -e "${YELLOW}[*] Target: ${GREEN}$TARGET${NC}"
    echo -e "${YELLOW}[*] Start Time: ${GREEN}$(date)${NC}"
    echo -e "${YELLOW}[*] Threads: ${GREEN}$THREADS${NC}"
    echo "========================================================================="
}

print_usage() {
    echo -e "${YELLOW}Usage: $0 -d <target.com> [-w wordlist.txt] [-t threads] [-o output_dir]${NC}"
    exit 1
}

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}[!] Tool '$1' not found. Install it to use this module.${NC}"
        return 1
    fi
}

validate_target() {
    if [[ ! "$TARGET" =~ ^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}[!] Invalid target format. Please provide a valid domain (e.g., example.com)${NC}"
        exit 1
    fi
}

init_recon() {
    echo -e "${GREEN}[+] Initializing reconnaissance on ${TARGET}${NC}"
    mkdir -p $OUTPUT_DIR/$TARGET/{subdomains,alive,js,params,dirs,ports,fingerprints,vulnscan,archive,screenshots,cloud,network}
}

# === Parse Args ===
while getopts "d:w:t:o:" opt; do
    case ${opt} in
        d ) TARGET=$OPTARG ;;
        w ) WORDLIST=$OPTARG ;;
        t ) THREADS=$OPTARG ;;
        o ) OUTPUT_DIR=$OPTARG ;;
        * ) print_usage ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    print_usage
fi

validate_target
print_banner
init_recon

# === Enhanced Recon Modules ===

# 1. Passive Subdomain Enumeration
echo -e "${BLUE}[*] Running passive subdomain enumeration${NC}"
if check_tool subfinder && check_tool amass; then
    subfinder -d $TARGET -silent -o $OUTPUT_DIR/$TARGET/subdomains/subfinder.txt &
    amass enum -passive -d $TARGET -o $OUTPUT_DIR/$TARGET/subdomains/amass.txt &
    wait
    cat $OUTPUT_DIR/$TARGET/subdomains/*.txt | sort -u > $OUTPUT_DIR/$TARGET/subdomains/all.txt
    echo -e "${GREEN}[+] Found $(wc -l < $OUTPUT_DIR/$TARGET/subdomains/all.txt) subdomains${NC}"
fi

# 2. DNS Resolution with parallel processing
echo -e "${BLUE}[*] Resolving DNS records${NC}"
if check_tool dnsx; then
    cat $OUTPUT_DIR/$TARGET/subdomains/all.txt | dnsx -silent -a -aaaa -cname -mx -txt -ptr -resp -o $OUTPUT_DIR/$TARGET/network/dns_records.json
fi

# 3. Fast Alive Check with parallel processing
echo -e "${BLUE}[*] Checking live hosts${NC}"
if check_tool httpx; then
    cat $OUTPUT_DIR/$TARGET/subdomains/all.txt | httpx -silent -threads $THREADS -status-code -title -tech-detect -cdn -ip -json -o $OUTPUT_DIR/$TARGET/alive/live.json
    jq -r '.url' $OUTPUT_DIR/$TARGET/alive/live.json > $OUTPUT_DIR/$TARGET/alive/live.txt
    echo -e "${GREEN}[+] Found $(wc -l < $OUTPUT_DIR/$TARGET/alive/live.txt) live hosts${NC}"
fi

# 4. Port Scanning with intelligent profiling
echo -e "${BLUE}[*] Running port scanning${NC}"
if check_tool naabu && check_tool nmap; then
    # Fast scan with naabu
    naabu -list $OUTPUT_DIR/$TARGET/alive/live.txt -top-ports 1000 -o $OUTPUT_DIR/$TARGET/ports/naabu.txt

    # Targeted nmap scan on interesting ports
    nmap -iL $OUTPUT_DIR/$TARGET/ports/naabu.txt -sV -sC --script=vuln -oA $OUTPUT_DIR/$TARGET/ports/nmap_scan
fi

# 5. Advanced Web Content Discovery
echo -e "${BLUE}[*] Running web content discovery${NC}"
if check_tool ffuf; then
    while read url; do
        ffuf -u $url/FUZZ -w $WORDLIST -t $THREADS -timeout $TIMEOUT -ac -ic -o $OUTPUT_DIR/$TARGET/dirs/$(echo $url | sed 's|https\?://||;s|/|_|g').json -of json &
    done < $OUTPUT_DIR/$TARGET/alive/live.txt
    wait
fi

# 6. JavaScript Analysis
echo -e "${BLUE}[*] Analyzing JavaScript files${NC}"
if check_tool gospider; then
    gospider -S $OUTPUT_DIR/$TARGET/alive/live.txt -o $OUTPUT_DIR/$TARGET/js -t $THREADS -d 2 -c 10 --other-source --include-subs
fi

# 7. Cloud Infrastructure Analysis
echo -e "${BLUE}[*] Checking cloud infrastructure${NC}"
if check_tool cloud_enum; then
    python3 cloud_enum.py -k $TARGET -l $OUTPUT_DIR/$TARGET/cloud/cloud_assets.txt
fi

# 8. Vulnerability Scanning
echo -e "${BLUE}[*] Running vulnerability scans${NC}"
if check_tool nuclei; then
    nuclei -l $OUTPUT_DIR/$TARGET/alive/live.txt -t cves/ -t vulnerabilities/ -t misconfiguration/ -o $OUTPUT_DIR/$TARGET/vulnscan/nuclei_results.txt
fi

# 9. Visual Recon with Screenshots
echo -e "${BLUE}[*] Capturing screenshots${NC}"
if check_tool aquatone; then
    cat $OUTPUT_DIR/$TARGET/alive/live.txt | aquatone -out $OUTPUT_DIR/$TARGET/screenshots
fi

# 10. ASN and Network Recon
echo -e "${BLUE}[*] Performing ASN and network reconnaissance${NC}"
if check_tool metabigor; then
    metabigor net -t $TARGET -o $OUTPUT_DIR/$TARGET/network/asn_info.txt
fi

# Final Report Generation
echo -e "${BLUE}[*] Generating final report${NC}"
{
    echo "# ÏSSACHAR'S RECON MASTER Report"
    echo "## Target: $TARGET"
    echo "## Date: $(date)"
    echo ""
    echo "## Summary"
    echo "- Subdomains Found: $(wc -l < $OUTPUT_DIR/$TARGET/subdomains/all.txt)"
    echo "- Live Hosts: $(wc -l < $OUTPUT_DIR/$TARGET/alive/live.txt)"
    echo "- Screenshots Captured: $(ls $OUTPUT_DIR/$TARGET/screenshots/aquatone_screenshots/ | wc -l)"
    echo ""
    echo "## Next Steps"
    echo "- Review the vulnerability scan results"
    echo "- Examine sensitive directories found"
    echo "- Analyze JavaScript files for secrets"
} > $OUTPUT_DIR/$TARGET/report.md

echo -e "${GREEN}[+] Recon completed for $TARGET at $(date)${NC}"
echo -e "${GREEN}[+] Results saved to: $OUTPUT_DIR/$TARGET/${NC}"
echo -e "${GREEN}[+] Report generated: $OUTPUT_DIR/$TARGET/report.md${NC}"
