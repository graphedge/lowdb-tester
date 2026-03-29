#!/bin/bash

# Configuration parser for SpecFarm
CONFIG_FILE=".specfarm/config"

get_config() {
    local key=$1
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'
    fi
}

set_config() {
    local key=$1
    local value=$2
    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        # Use a temporary file for sed to be safe on different platforms
        sed "s/^${key}=.*/${key}="${value}"/" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    else
        echo "${key}="${value}"" >> "$CONFIG_FILE"
    fi
}
