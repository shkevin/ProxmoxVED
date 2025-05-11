#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/shkevin/ProxmoxVED/refs/heads/overleaf-support/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Kevin Cox (shkevin)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/overleaf/overleaf

# App Default Values
APP="Overleaf"
var_tags="${var_tags:-debian;latex}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -d /opt/overleaf/toolkit ]]; then
        msg_error "No ${APP} Installation Found!"
        exit 1
    fi

    RELEASE=$(curl -fsSL https://api.github.com/repos/overleaf/overleaf/releases/latest |
        grep "tag_name" | sed -E 's/.*"v?([^"]+)".*/\1/')

    CURRENT_RELEASE=""
    [[ -f /opt/${APP}_version.txt ]] && CURRENT_RELEASE=$(</opt/${APP}_version.txt)

    if [[ "$RELEASE" != "$CURRENT_RELEASE" ]]; then
        msg_info "Stopping $APP"
        cd /opt/overleaf/toolkit
        ./bin/stop
        msg_ok "Stopped $APP"

        msg_info "Creating Backup"
        tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" /opt/overleaf/data /opt/overleaf/toolkit/config
        msg_ok "Backup Created"

        msg_info "Updating $APP to $RELEASE"
        git -C /opt/overleaf/toolkit fetch --tags
        git -C /opt/overleaf/toolkit checkout "tags/v${RELEASE}" -f
        msg_ok "Updated $APP to $RELEASE"

        msg_info "Installing updated Node.js modules (if needed)"
        NODE_VERSION="22" NODE_MODULE="pnpm@latest" install_node_and_modules
        msg_ok "Node modules ensured"

        msg_info "Starting $APP"
        ./bin/up
        msg_ok "Started $APP"

        echo "$RELEASE" >/opt/${APP}_version.txt

        msg_info "Cleaning up backups older than 7 days"
        find /opt -name "${APP}_backup_*.tar.gz" -mtime +7 -delete
        msg_ok "Cleanup Completed"
    else
        msg_ok "No update required. ${APP} is already at v${RELEASE}"
    fi

    exit 0
}

start
build_container
description

msg_ok "Completed Successfully!"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
