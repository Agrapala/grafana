# Server Monitoring Stack
**Prometheus + Grafana + Alertmanager — Rocky Linux 9 / Contabo VPS**

---

## Architecture

```
Your Contabo Servers          Monitoring Host (1 server)
┌─────────────────┐           ┌─────────────────────────────────┐
│ server-1:9100   │──scrape──▶│ Prometheus :9090                │
│ server-2:9100   │──scrape──▶│   └── stores metrics (30 days)  │
│ server-3:9100   │──scrape──▶│                                  │
└─────────────────┘           │ Grafana :3000                   │
                              │   └── dashboards & charts        │
                              │                                  │
                              │ Alertmanager :9093              │
                              │   └── email / Slack alerts       │
                              └─────────────────────────────────┘
```

---

## Step 1 — Set up the monitoring host

Pick one of your Contabo servers to be the monitoring host (or spin up a cheap extra one).

### Install Docker & Docker Compose
```bash
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
```

### Upload and start the stack
```bash
# Upload this folder to your monitoring server
scp -r monitoring/ root@YOUR_MONITOR_IP:/opt/monitoring

ssh root@YOUR_MONITOR_IP
cd /opt/monitoring
docker compose up -d
```

Open firewall ports on the monitoring host:
```bash
firewall-cmd --permanent --add-port=3000/tcp   # Grafana
firewall-cmd --permanent --add-port=9090/tcp   # Prometheus (optional, internal use)
firewall-cmd --permanent --add-port=9093/tcp   # Alertmanager (optional)
firewall-cmd --reload
```

---

## Step 2 — Install Node Exporter on each server to monitor

Run this on **every** Contabo server you want to monitor:
```bash
scp install_node_exporter.sh root@YOUR_SERVER_IP:/tmp/
ssh root@YOUR_SERVER_IP "bash /tmp/install_node_exporter.sh"
```

---

## Step 3 — Add your server IPs to Prometheus

Edit `prometheus/prometheus.yml` and replace the placeholder IPs:
```yaml
- targets:
    - "45.12.34.10:9100"   # web-01
    - "45.12.34.11:9100"   # db-01
    - "45.12.34.12:9100"   # app-02
```

Reload Prometheus (no restart needed):
```bash
curl -X POST http://localhost:9090/-/reload
```

---

## Step 4 — Set up Grafana

1. Open `http://YOUR_MONITOR_IP:3000`
2. Login: `admin` / `changeme` (change this immediately in `docker-compose.yml`)
3. Prometheus is already connected automatically
4. The built-in dashboard provisioning now includes a **Systemd Service State** dashboard that shows running and failed services for any server scraped by Node Exporter.
5. If you also want the full host metrics view, import the Node Exporter dashboard: **Dashboards → Import → ID `1860`** (Node Exporter Full)

The service-state panels depend on Node Exporter running with the `systemd` collector enabled, which the included `install_node_exporter.sh` already configures.

---

## Step 5 — Configure alerts (email)

Edit `alertmanager/alertmanager.yml`:
- Set your SMTP server details
- Set `to:` to your email address

Restart alertmanager:
```bash
docker compose restart alertmanager
```

---

## Useful commands

| Task | Command |
|------|---------|
| View all logs | `docker compose logs -f` |
| Restart stack | `docker compose restart` |
| Stop stack | `docker compose down` |
| Update images | `docker compose pull && docker compose up -d` |
| Check targets | Open http://YOUR_MONITOR_IP:9090/targets |
| Check alerts | Open http://YOUR_MONITOR_IP:9093 |

---

## Alert thresholds (edit in `prometheus/alert.rules.yml`)

Server unreachable for 1 minute
HighCPU Usage CPU > 85% for 5 minutes
CriticalCPU Usage CPU > 95% for 2 minutes
HighMemory UsageMemory > 80% for 5 minutes
CriticalMemory UsageMemory > 95% for 2 minutes
HighDisk UsageDisk > 80% for 5 minutesC
riticalDisk UsageDisk > 90% for 2 minutes
HighLoad AverageLoad > 2× CPU cores for 5 minutes
HighNetwork ErrorsNetwork errors > 10/sec for 5 minutes
