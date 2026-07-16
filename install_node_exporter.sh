#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Node Exporter installer for Rocky Linux 9
#  Run as root on each Contabo server you want to monitor:
#    bash install_node_exporter.sh
# ─────────────────────────────────────────────────────────────

set -e

NODE_EXPORTER_VERSION="1.8.0"
ARCH="linux-amd64"
URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz"

echo "==> Installing Node Exporter v${NODE_EXPORTER_VERSION}..."

# 1. Download & extract
# 1. Stop existing Node Exporter before upgrade
if systemctl is-active --quiet node_exporter; then
    echo "==> Stopping existing Node Exporter..."
    systemctl stop node_exporter
fi

# 2. Download & extract
cd /tmp
curl -fsSL "$URL" -o node_exporter.tar.gz
tar xzf node_exporter.tar.gz

echo "==> Installing binary..."
cp -f node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}/node_exporter /usr/local/bin/node_exporter
chmod +x /usr/local/bin/node_exporter

rm -rf node_exporter.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}

# 2. Create dedicated user
id node_exporter &>/dev/null || useradd -rs /bin/false node_exporter

# 3. Create systemd service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter \\
  --collector.systemd \\
  --collector.processes

[Install]
WantedBy=multi-user.target
EOF

# 4. Open firewall port 9100
echo "==> Opening firewall port 9100..."
firewall-cmd --permanent --add-port=9100/tcp
firewall-cmd --reload

# 5. Enable & start service
systemctl daemon-reload
systemctl enable --now node_exporter

# 6. Verify
sleep 2
if systemctl is-active --quiet node_exporter; then
  echo ""
  echo "✓  Node Exporter is running on port 9100"
  echo "✓  Test: curl http://localhost:9100/metrics | head -5"
  echo ""
  echo "Now add this server's IP to prometheus/prometheus.yml on your monitoring host."
else
  echo "✗  Something went wrong. Check: journalctl -u node_exporter -n 30"
  exit 1
fi
