#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/shkevin/ProxmoxVED/refs/heads/overleaf-support/misc/build.func)
# Author: kcox
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/overleaf/overleaf
# App Default Values
APP="Overleaf"
var_tags="latex;editor"
var_cpu="2"
var_ram="2048"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"
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
    exit
  fi
  RELEASE=$(curl -fsSL https://api.github.com/repos/overleaf/toolkit/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    msg_info "Stopping $APP"
    cd /opt/overleaf/toolkit
    ./bin/stop
    msg_ok "Stopped $APP"
    msg_info "Creating Backup"
    tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" /opt/overleaf/data /opt/overleaf/toolkit/config
    msg_ok "Backup Created"
    msg_info "Updating $APP to ${RELEASE}"
    cd /opt/overleaf/toolkit
    git pull
    msg_ok "Updated $APP to ${RELEASE}"
    msg_info "Starting $APP"
    ./bin/up
    msg_ok "Started $APP"
    msg_info "Cleaning Up"
    find /opt -name "${APP}_backup_*.tar.gz" -mtime +7 -delete
    msg_ok "Cleanup Completed"
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}
start
build_container
description
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
