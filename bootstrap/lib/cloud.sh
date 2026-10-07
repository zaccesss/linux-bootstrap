#!/usr/bin/env bash
#
# cloud and DevOps tooling. Terraform and kubectl are not in Ubuntu's archive, so they come from
# HashiCorp's and the Kubernetes project's own APT repositories. The AWS CLI comes from AWS's
# official v2 installer, because Ubuntu either does not package it or ships the retired v1.

readonly CLOUD_PACKAGES=(
    ansible
    docker.io
    docker-compose-v2
)

# from the vendor repositories added by add_cloud_repositories
readonly CLOUD_VENDOR_PACKAGES=(
    terraform
    kubectl
)

add_cloud_repositories() {
    add_apt_repository_with_key \
        "hashicorp" \
        "https://apt.releases.hashicorp.com/gpg" \
        "https://apt.releases.hashicorp.com ${PLATFORM_CODENAME} main"

    # Kubernetes publishes one repository per minor version, so follow the current stable minor;
    # kubectl supports one minor version either side of the cluster it talks to
    local kubernetes_minor="v1.37"
    if ! is_test_mode; then
        kubernetes_minor="$(curl -fsSL https://dl.k8s.io/release/stable.txt | cut -d. -f1,2)"
    fi

    add_apt_repository_with_key \
        "kubernetes" \
        "https://pkgs.k8s.io/core:/stable:/${kubernetes_minor}/deb/Release.key" \
        "https://pkgs.k8s.io/core:/stable:/${kubernetes_minor}/deb/ /"
}

install_aws_cli() {
    local archive
    local extract_dir

    archive="$(download "https://awscli.amazonaws.com/awscli-exe-linux-${PLATFORM_MACHINE}.zip")"
    extract_dir="$(mktemp -d)"
    unzip -q "$archive" -d "$extract_dir"

    # --update replaces an existing install in place, which keeps re-runs safe
    as_root "$extract_dir/aws/install" --update
    rm -rf "$extract_dir" "$archive"
}

# Docker's socket is owned by the docker group; joining it avoids sudo for every docker command
grant_docker_access() {
    if is_test_mode || is_simulate_mode || id -nG "$USER" | grep -qw docker; then
        return 0
    fi

    as_root usermod -aG docker "$USER"
    log_warn "Added ${USER} to the docker group; log out and back in for it to apply"
}

# commands the final check expects on PATH. The test suite reads this list, so keep it in step
# with the packages and installers above
readonly CLOUD_COMMANDS=(
    ansible
    aws
    docker
    kubectl
    terraform
)

verify_cloud_tooling() {
    verify_commands "Cloud and DevOps" "${CLOUD_COMMANDS[@]}"

    # Compose v2 is a docker plugin rather than its own command, so it is checked through docker
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose v2 is unavailable (docker compose version failed)"
        return 1
    fi
}

install_cloud_tooling() {
    add_cloud_repositories

    log_info "Installing cloud and DevOps packages"
    apt_install "${CLOUD_PACKAGES[@]}" "${CLOUD_VENDOR_PACKAGES[@]}"
    grant_docker_access

    if ! external_installers_enabled; then
        log_info "Skipping the AWS CLI installer in test or simulate mode"
        return 0
    fi

    install_aws_cli
    verify_cloud_tooling
}
