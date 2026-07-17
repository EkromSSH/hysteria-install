#!/bin/bash
while true; do
  UPTIME=$(uptime -p | sed 's/up //')
  DISK=$(df -h / | awk 'NR==2{print $3"/"$2}')
  echo '{"uptime":"'$UPTIME'","disk":"'$DISK'"}'
  sleep 30
done
