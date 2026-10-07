#!/usr/bin/env bash

log_info() {
    printf '[INFO] %s\n' "$*"
}

log_success() {
    printf '[ OK ] %s\n' "$*"
}

log_warn() {
    printf '[WARN] %s\n' "$*" >&2
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

handle_error() {
    local line="$1"
    local command="$2"
    local exit_code="$3"

    log_error "Bootstrap failed at line ${line}: ${command}"
    log_error "Exit code: ${exit_code}"

    return "$exit_code"
}
