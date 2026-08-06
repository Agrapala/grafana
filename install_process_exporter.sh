#!/bin/bash
set -e

VERSION="0.8.7"
ARCH="linux-amd64"
FILENAME="process-exporter-${VERSION}.${ARCH}.tar.gz"
MONITORING_HOST="207.180.252.87"   # ← your monitoring host IP
SERVE_PORT="8888"

echo "==> Installing Process Exporter v${VERSION} on $(hostname)..."

# 1. Stop existing if running
if systemctl is-active --quiet process-exporter 2>/dev/null; then
  echo "==> Stopping existing Process Exporter..."
  systemctl stop process-exporter
fi

# 2. Download from monitoring host
echo "==> Downloading from http://${MONITORING_HOST}:${SERVE_PORT}/${FILENAME}..."
cd /tmp
curl -fsSL "http://${MONITORING_HOST}:${SERVE_PORT}/${FILENAME}" -o ${FILENAME}
echo "✓  Downloaded"

# 3. Extract & install binary
tar xzf ${FILENAME}
cp -f process-exporter-${VERSION}.${ARCH}/process-exporter /usr/local/bin/process-exporter
chmod +x /usr/local/bin/process-exporter
rm -rf ${FILENAME} process-exporter-${VERSION}.${ARCH}
echo "✓  Binary installed"

# 4. Create config
echo "==> Creating config..."
cat > /etc/process-exporter.yml <<CONF
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

  - name: "sshd"
    cmdline:
      - sshd
CONF
echo "✓  Config created"

# 5. Create systemd service
echo "==> Creating systemd service..."
cat > /etc/systemd/system/process-exporter.service <<SVC
[Unit]
Description=Process Exporter
Documentation=https://github.com/ncabatoff/process-exporter
After=network-online.target

[Service]
User=root
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/process-exporter \
  --config.path=/etc/process-exporter.yml \
  --web.listen-address=:9256

[Install]
WantedBy=multi-user.target
SVC

# 6. Open firewall
echo "==> Opening firewall port 9256..."
firewall-cmd --permanent --add-port=9256/tcp
firewall-cmd --reload

# 7. Enable & start
systemctl daemon-reload
systemctl enable --now process-exporter

# 8. Verify
sleep 2
if systemctl is-active --quiet process-exporter; then
  echo ""
  echo "✓  Process Exporter running on port 9256"
  echo ""
  echo "==> Detected service metrics:"
  curl -s http://localhost:9256/metrics | grep namedprocess_namegroup_num_procs | head -10
  echo ""
  echo "✓  Add to prometheus.yml on monitoring host:"
  echo "     - \"$(hostname -I | awk '{print $1}'):9256\""
else
  echo "✗  Something went wrong. Check: journalctl -u process-exporter -n 30"
  exit 1
fi