#!/bin/bash

DIR="/var/lib/node_exporter/textfile_collector"
FILE="$DIR/auth_monitor.prom"

mkdir -p $DIR

TODAY=$(date +"%b %e")

# Failed login attempts today

FAILED=$(grep "$TODAY" /var/log/secure | grep "Failed password" | wc -l)

# Unique IPs causing failed logins

FAILED_IPS=$(grep "$TODAY" /var/log/secure | \
grep "Failed password" | \
grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
awk '{print $2}' | \
sort -u | \
wc -l)

# Top attacking IPs

grep "$TODAY" /var/log/secure | \
grep "Failed password" | \
grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
awk '{print $2}' | \
sort | \
uniq -c | \
sort -nr | \
head -10 | \
awk '
{
 print "failed_login_ip_attempts{ip=\"" $2 "\"} " $1
}
' > /tmp/failed_ips.prom


# Current active users

ACTIVE_USERS=$(who | awk '{print $1}' | sort -u | wc -l)


cat > $FILE <<EOF
# HELP login_failed_today Total failed login attempts today
# TYPE login_failed_today gauge
login_failed_today $FAILED

# HELP failed_login_unique_ips_today Unique IPs causing failed logins today
# TYPE failed_login_unique_ips_today gauge
failed_login_unique_ips_today $FAILED_IPS

# HELP active_users_now Current active logged in users
# TYPE active_users_now gauge
active_users_now $ACTIVE_USERS
EOF

cat /tmp/failed_ips.prom >> $FILE
