#!/bin/bash

set -e

PROCESS_EXPORTER_VERSION="0.8.7"
ARCH="linux-amd64"
URL="https://github.com/ncabatoff/process-exporter/releases/download/v${PROCESS_EXPORTER_VERSION}/process-exporter_${PROCESS_EXPORTER_VERSION}_${ARCH}.tar.gz"

echo "==> Installing Process Exporter v${PROCESS_EXPORTER_VERSION}..."

# 1. Stop existing Process Exporter before upgrade
if systemctl is-active --quiet process-exporter; then
  echo "==> Stopping existing Process Exporter..."
  systemctl stop process-exporter
fi

# 2. Download & extract
cd /tmp
curl -fsSL "$URL" -o process-exporter.tar.gz
tar xzf process-exporter.tar.gz

echo "==> Installing binary..."
cp -f process-exporter-${PROCESS_EXPORTER_VERSION}_${ARCH}/process-exporter /usr/local/bin/process-exporter
chmod +x /usr/local/bin/process-exporter

rm -rf process-exporter.tar.gz process-exporter-${PROCESS_EXPORTER_VERSION}_${ARCH}

# 3. Create config file with your services
echo "==> Creating config file..."
cat > /etc/process-exporter.yml <<EOF
process_names:
  - name: "nginx"
    cmdline:
      - nginx

  - name: "mongod"
    cmdline:
      - mongod

  - name: "senzagro"
    cmdline:
      - senzagro

  - name: "vernemq"
    cmdline:
      - vernemq

  - name: "filebeat"
    cmdline:
      - filebeat

  - name: "metricbeat"
    cmdline:
      - metricbeat

  - name: "node_exporter"
    cmdline:
      - node_exporter

  - name: "sshd"
    cmdline:
      - sshd
EOF

# 4. Create systemd service
echo "==> Creating systemd service..."
cat > /etc/systemd/system/process-exporter.service <<EOF
[Unit]
Description=Process Exporter
Documentation=https://github.com/ncabatoff/process-exporter
After=network-online.target

[Service]
User=root
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/process-exporter \\
  --config.path=/etc/process-exporter.yml \\
  --web.listen-address=:9256

[Install]
WantedBy=multi-user.target
EOF

# 5. Open firewall port 9256
echo "==> Opening firewall port 9256..."
firewall-cmd --permanent --add-port=9256/tcp
firewall-cmd --reload

# 6. Enable & start service
systemctl daemon-reload
systemctl enable --now process-exporter

# 7. Verify
sleep 2
if systemctl is-active --quiet process-exporter; then
  echo ""
  echo "✓  Process Exporter is running on port 9256"
  echo ""
  echo "==> Verifying metrics..."
  curl -s http://localhost:9256/metrics | grep namedprocess_namegroup_num_procs | head -10
  echo ""
  echo "✓  Now add this server's IP to prometheus.yml:"
  echo "     - job_name: \"process-exporter\""
  echo "       static_configs:"
  echo "         - targets:"
  echo "             - \"$(hostname -I | awk '{print $1}'):9256\""
else
  echo "✗  Something went wrong. Check: journalctl -u process-exporter -n 30"
  exit 1
fi