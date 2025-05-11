#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Kevin Cox (shkevin)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/overleaf/overleaf

# Import Proxmox Community Script Functions
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Application Constants
APP="Overleaf"
APP_DIR="/opt/overleaf"
VERSION_FILE="/opt/${APP}_version.txt"
TMP_DIR="/tmp/overleaf-install"

# Ensure base directories
mkdir -p "$TMP_DIR" "$APP_DIR"

# Install Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y \
    build-essential \
    wget \
    net-tools \
    unzip \
    time \
    imagemagick \
    optipng \
    strace \
    nginx \
    git \
    python3 \
    python-is-python3 \
    zlib1g-dev \
    libpcre3-dev \
    gettext-base \
    libwww-perl \
    ca-certificates \
    curl \
    gnupg \
    qpdf \
    logrotate \
    cron \
    runit
msg_ok "Installed Dependencies"

# Install MongoDB and Redis
msg_info "Installing MongoDB"
MONGODB_VERSION="6.0" install_mongodb
msg_ok "Installed MongoDB"

msg_info "Installing Redis"
$STD apt-get install -y redis-server
systemctl enable -q --now redis-server
msg_ok "Installed Redis"

# Install Node.js and pnpm
msg_info "Installing Node.js and pnpm"
NODE_VERSION="22" NODE_MODULE="pnpm@latest" install_node_and_modules
msg_ok "Installed Node.js and pnpm"

# Install TeXLive basic
msg_info "Installing TeXLive"
TEXLIVE_MIRROR="https://mirror.ox.ac.uk/sites/ctan.org/systems/texlive/tlnet"
cd "$TMP_DIR"
wget -q "${TEXLIVE_MIRROR}/install-tl-unx.tar.gz"
tar -xzf install-tl-unx.tar.gz --strip-components=1 -C install-tl-unx
cat <<EOF >texlive.profile
selected_scheme scheme-basic
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
$STD install-tl-unx/install-tl -profile texlive.profile -repository "$TEXLIVE_MIRROR"
export PATH="/usr/local/texlive/bin/x86_64-linux:$PATH"
msg_ok "Installed TeXLive"

# Download Overleaf CE
msg_info "Cloning Overleaf CE"
git clone -q https://github.com/overleaf/overleaf.git "$APP_DIR"
cd "$APP_DIR"
RELEASE=$(git describe --tags $(git rev-list --tags --max-count=1))
echo "$RELEASE" >"$VERSION_FILE"
msg_ok "Cloned Overleaf CE"

# Build Overleaf
msg_info "Installing Node Modules"
pnpm install --frozen-lockfile --prefer-offline
msg_ok "Installed Node Modules"

msg_info "Building Overleaf"
node genScript.js install | bash
node genScript.js compile | bash
msg_ok "Built Overleaf"

# Configure Latexmk
mkdir -p /usr/local/share/latexmk/LatexMk
cp server-ce/config/latexmkrc /usr/local/share/latexmk/LatexMk

# Configure nginx
msg_info "Configuring nginx"
cp server-ce/nginx/overleaf.conf /etc/nginx/sites-enabled/overleaf.conf
rm -f /etc/nginx/sites-enabled/default
cp server-ce/nginx/nginx.conf.template /etc/nginx/nginx.conf
msg_ok "Configured nginx"

# Environment Setup
mkdir -p /etc/overleaf
cp server-ce/config/settings.js /etc/overleaf/settings.js
cp server-ce/config/env.sh /etc/overleaf/env.sh
touch /etc/overleaf/site_status

# Setup cron
cp server-ce/config/crontab-* /etc/cron.d/
chmod 600 /etc/cron.d/crontab-*

# Setup logrotate
cp server-ce/logrotate/overleaf /etc/logrotate.d/overleaf
chmod 644 /etc/logrotate.d/overleaf

# Setup systemd service
msg_info "Creating systemd service"
cat <<EOF >/etc/systemd/system/overleaf.service
[Unit]
Description=Overleaf CE
After=network.target mongod.service redis-server.service

[Service]
Type=simple
Environment=OVERLEAF_CONFIG=/etc/overleaf/settings.js
WorkingDirectory=${APP_DIR}
ExecStart=$(which pnpm) start
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable -q --now overleaf
msg_ok "Created and started systemd service"

# Cleanup
msg_info "Cleaning up"
rm -rf "$TMP_DIR"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned up"

motd_ssh
customize
msg_ok "${APP} installation completed successfully!"
