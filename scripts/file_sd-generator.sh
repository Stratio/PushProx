#!/usr/bin/env bash

PROXY=$1
shift
EXPORTER_PORT=$1
shift
LABELS=$@


### FUNCTIONS ###

# Usage function
function usage(){
    echo "This script queries pushprox-proxy clients and prints configuration for Prometheus exporter ports and labels."
    echo -e "It's intended to use in crontab to generate the dynamic file used by file_sd_config configuration\n"
    echo "Usage: $0 <proxy_url> <exporter_port> [label1_name:label1_value label2_name:label2_value ... labelN_name:labelN_value]"
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


# Function that prints the prometheys file_sd_config
function print_sd_config(){
    local proxy=$1
    shift
    local exporter_port=$1
    shift
    local labels=( $@ )
    local tmp label_name label_value
    tmp=$(mktemp -p /dev/shm pushprox_sd_config.XXXX)
    curl -s "$proxy/clients" | jq '.[] .targets[]' -r | sort > "$tmp"
    echo -e '[\n  {\n    "targets": ['
    readarray -t clients < "$tmp"
    for ((i=0;i<${#clients[@]};i++)){
        if ((i<${#clients[@]}-1)); then
            echo "      \"${clients[$i]}:$exporter_port\","
        else
            echo "      \"${clients[$i]}:$exporter_port\""
        fi
    }
    if [[ $labels ]]; then
        echo -e "    ],\n    \"labels\": {"
        for ((i=0;i<${#labels[@]};i++)){
            label=${labels[$i]}
            label_name=${label%%:*}
            label_value=${label##*:}
            if ((i<${#labels[@]}-1)); then
                echo -e "      \"$label_name\": \"$label_value\","
            else
                echo -e "      \"$label_name\": \"$label_value\""
            fi
        }
        echo -e "    }\n  }\n]"
    else
        echo -e "    ]\n  }\n]"
    fi
}
### FUNCTIONS ###


### MAIN ###

# Exit if no PROXY specified
if [[ ! $PROXY ]] || [[ ! $EXPORTER_PORT ]] || [[ ! $PROXY =~ ^[a-zA-Z0-9_-.]+:[0-9]+$ ]]; then
    usage
    exit 1
fi

# Exit if no jq found
if ! command -v jq > /dev/null; then
    echo "Command 'jq' is needed!"
    exit 1
fi

check_connectivity "$PROXY"
print_sd_config "$PROXY" "$EXPORTER_PORT" "$LABELS"
### MAIN ###
