cat /usr/local/bin/check_logged_users.sh 
#!/bin/bash

DIR="/var/lib/node_exporter/textfile_collector"

mkdir -p $DIR

OUTPUT="$DIR/logged_users.prom"

echo "# HELP logged_users Current logged in users" > $OUTPUT
echo "# TYPE logged_users gauge" >> $OUTPUT

who | awk '{print $1}' | sort | uniq -c | while read count user
do
    echo "logged_users{username=\"$user\"} $count" >> $OUTPUT
done
