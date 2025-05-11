#!/usr/bin/env bash
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os
msg_info "Installing Dependencies"
$STD apt-get install -y \
    curl \
    sudo \
    mc \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    git \
    python3-pip
msg_ok "Installed Dependencies"
msg_info "Installing Docker"
$STD curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable -q --now docker
msg_ok "Installed Docker"
msg_info "Installing Docker Compose"
$STD curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
msg_ok "Installed Docker Compose"
msg_info "Setup Overleaf"
mkdir -p /opt/overleaf
cd /opt/overleaf
RELEASE=$(curl -fsSL https://api.github.com/repos/overleaf/toolkit/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
git clone https://github.com/overleaf/toolkit.git /opt/overleaf/toolkit
cd /opt/overleaf/toolkit
mkdir -p config/
cat >config/overleaf.rc <<EOF
SERVER_PRO=false
PROJECT_NAME=overleaf
OVERLEAF_DATA_PATH=/opt/overleaf/data
OVERLEAF_PORT=3000
MONGO_URL=mongodb://mongo/sharelatex
REDIS_HOST=redis
REDIS_PORT=6379
EOF
cat >config/variables.env <<EOF
OVERLEAF_MONGO_URL=mongodb://mongo/sharelatex
OVERLEAF_REDIS_HOST=redis
OVERLEAF_REDIS_PORT=6379
OVERLEAF_APP_NAME=Overleaf Community Edition
OVERLEAF_SITE_URL=http://localhost:3000
OVERLEAF_NAV_TITLE=Overleaf Community Edition
OVERLEAF_HEADER_IMAGE_URL=http://localhost:3000/img/ol-brand.svg
OVERLEAF_ADMIN_EMAIL=admin@overleaf.com
ENABLED_LINKED_FILE_TYPES=url,project_file
ENABLE_CONVERSIONS=true
EMAIL_CONFIRMATION_DISABLED=true
EOF
echo "${RELEASE}" >/opt/overleaf_version.txt
msg_ok "Setup Overleaf"
msg_info "Starting Overleaf"
$STD ./bin/up
msg_ok "Started Overleaf"
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/overleaf.service
[Unit]
Description=Overleaf Community Edition
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/overleaf/toolkit
ExecStart=/opt/overleaf/toolkit/bin/up
ExecStop=/opt/overleaf/toolkit/bin/stop
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now overleaf
msg_ok "Created Service"
motd_ssh
customize
msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
