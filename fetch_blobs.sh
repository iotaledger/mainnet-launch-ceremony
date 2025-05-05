#!/bin/bash

set -e

BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

BASE_URL="https://dbfiles.mainnet.iota.cafe"

FILES=(
    "latest-full_snapshot_17011901.bin"
    "migration.blob"
    "stardust_object_snapshot.bin"
    "genesis.blob"
)

print_header() {
    echo -e "\n${BOLD}${MAGENTA}$1${RESET}"
    echo -e "${CYAN}$(printf '%0.s=' $(seq 1 50))${RESET}"
}

download_file() {
    local file=$1
    local url="${BASE_URL}/${file}"
    
    echo -e "\n${CYAN}[FILE: ${BOLD}$file${RESET}${CYAN}]${RESET}"
    echo -e "${CYAN}$(printf '%0.s-' $(seq 1 40))${RESET}"
    
    if [ -f "$file" ]; then
        echo -e "File already exists. Skipping download."
        return 0
    fi
    
    echo -e "Download From $url"
    HTTP_STATUS=$(curl -s -I "$url" | grep HTTP | awk '{print $2}')
    
    if [[ "$HTTP_STATUS" == "404" ]]; then
        echo -e "${YELLOW}Not found. The ceremony master may not have uploaded it yet.${RESET}"
        return 0
    fi

    curl -# -L -o "$(basename "$url")" "$url"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed.${RESET}"
        return 1
    fi
    
    echo -e "Download completed successfully."
    return 0
}

verify_checksum() {
    local file=$1
    local sha_file="${file}.sha256"
    local verification_status=0  # 0 = not verified, 1 = verified, 2 = mismatch

    echo -e "\n${CYAN}[FILE: ${BOLD}$file${RESET}${CYAN}]${RESET}"
    echo -e "${CYAN}$(printf '%0.s-' $(seq 1 40))${RESET}"
    
    if [ -f "$file" ] && [ -f "$sha_file" ]; then
        expected_sha256=$(cat "$sha_file")
        actual_sha256=$(sha256sum "$file" | awk '{print $1}')
        
        if [ "$expected_sha256" = "$actual_sha256" ]; then
            echo -e "SHA256 checksum verified ✓"
            verification_status=1
        else
            echo -e "${RED}SHA256 checksum mismatch!${RESET}"
            echo -e "  Expected: $expected_sha256"
            echo -e "  Actual: $actual_sha256"
            verification_status=2
        fi
    elif [ -f "$file" ]; then
        echo -e "${YELLOW}No SHA256 checksum file found. Skipping verification.${RESET}"
        verification_status=0
    fi
    
    eval "VERIFICATION_STATUS_${file//[^a-zA-Z0-9]/_}=$verification_status"
}

print_header "Starting to download the missing files in the repo."

for file in "${FILES[@]}"; do
    download_file "$file"
done

print_header "Starting to verify the downloaded files"

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        verify_checksum "$file"
    fi
done

print_header "Summary"

echo -e "${BOLD}Files processed:${RESET}"
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        verification_status_var="VERIFICATION_STATUS_${file//[^a-zA-Z0-9]/_}"
        verification_status=$(eval "echo \$$verification_status_var")
        case $verification_status in
            1) # Verified
                echo -e "  ${GREEN}[✓]${RESET} ${BOLD}$file${RESET} - ${GREEN}Available (Verified)${RESET}"
                ;;
            2) # Mismatch
                echo -e "  ${RED}[✗]${RESET} ${BOLD}$file${RESET} - ${RED}Corrupted (SHA256 mismatch)${RESET}"
                ;;
            *) # Not verified or no checksum file
                echo -e "  ${YELLOW}[⚠]${RESET} ${BOLD}$file${RESET} - ${YELLOW}Available (Not verified)${RESET}"
                ;;
        esac
    else
        echo -e "  ${RED}[✗]${RESET} ${BOLD}$file${RESET} - ${RED}Not available${RESET}"
    fi
done

echo -e "\nAll operations completed.\n"
