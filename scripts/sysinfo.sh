#!/bin/bash
WWW="/home/vps/public_html/server"
mkdir -p "$WWW"

while true; do
  # Delta-based CPU (1s sample)
  C1=$(awk 'NR==1{print $2+$4+$5}' /proc/stat)
  I1=$(awk 'NR==1{print $2+$4}' /proc/stat)
  sleep 1
  C2=$(awk 'NR==1{print $2+$4+$5}' /proc/stat)
  I2=$(awk 'NR==1{print $2+$4}' /proc/stat)
  CPU=$(awk -v u=$((I2-I1)) -v c=$((C2-C1)) 'BEGIN{if(c>0)printf "%d",u*100/c;else print 0}')

  UPTIME=$(uptime -p | sed 's/up //')
  RAM_U=$(free -m | awk '/^Mem:/{print $3}')
  RAM_T=$(free -m | awk '/^Mem:/{print $2}')
  DISK=$(df -h / | awk 'NR==2{print $3"/"$2}')

  echo "[{\"uptime\":\"$UPTIME\",\"cpu_usage\":\"${CPU:-0}%\",\"ram_usage\":\"$RAM_U/${RAM_T}MB\",\"disk_usage\":\"$DISK\"}]" > "$WWW/sysinfo.json"
  sleep 29
done
