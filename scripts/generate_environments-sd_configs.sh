#!/usr/bin/env bash

DIRNAME=$(dirname $0)

CONFIG="$DIRNAME/environments.list"
FILE_SD_CONFIG_DIR="$DIRNAME/file_sd_configs"
FILE_SD_GENERATOR="$DIRNAME/file_sd-generator.sh"


### FUNCTIONS ###
# Usage function
function usage(){
    echo "This script generates all file_sd_configs for Prometheus based on $CONFIG"
    echo -e "It's intended to be used in crontab\n"
    echo "Usage: $0"
}

# Check connectivity agains pushprox proxy
function check_connectivity(){
    local host=${1%%:*}
    local port=${1##*:}
    if ! timeout 2 bash -c "</dev/tcp/$host/$port"; then
        echo "Cannot establish connection to http://$host:$port"
        return 1
    fi
}
### FUNCTIONS ###


### MAIN ###
# Exit if no jq found
if ! command -v jq > /dev/null; then
    echo "Command 'jq' is needed!"
    exit 1
fi

declare -A tmpconfig
while IFS=$' ' read proxy port labels config; do
        labels=${labels//,/ }
        check_connectivity "$proxy" >/dev/null 2>&1 || { echo "$proxy unreachable!" ; continue; }
        if [[ ! ${tmpconfig[$config]} ]]; then
            tmpconfig["$config"]=$(mktemp -p /dev/shm gen_sd_configs.XXXX)
            "$FILE_SD_GENERATOR" "$proxy" "$port" "$labels" > "${tmpconfig[$config]}"
        else
            tmp=$(mktemp -p /dev/shm aux_gen_sd_configs.XXXX)
            # Backup data for already existent data for $config
            cp "${tmpconfig[$config]}" "$tmp"
            # Generate & add additional configuration
            { cat "$tmp" ; "$FILE_SD_GENERATOR" "$proxy" "$port" "$labels" ; } | jq -s 'add' > "${tmpconfig[$config]}"
            rm -f "$tmp"
        fi
done< <(grep -v ^# "$CONFIG" | grep .)

# Generate file_sd_configs and remove temporal files
mkdir -p "$FILE_SD_CONFIG_DIR"
for config in "${!tmpconfig[@]}"; do
    cat "${tmpconfig[$config]}" > "$FILE_SD_CONFIG_DIR/$config"
    rm -f "${tmpconfig[$config]}"
done
### MAIN ###
