#!/bin/bash
while true; do
  RX=$(vnstat --json d 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); dx=d.get('interfaces',[{}])[0].get('traffic',{}).get('days',[{}])[0]; print(dx.get('rx',0))" 2>/dev/null || echo 0)
  TX=$(vnstat --json d 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); dx=d.get('interfaces',[{}])[0].get('traffic',{}).get('days',[{}])[0]; print(dx.get('tx',0))" 2>/dev/null || echo 0)
  echo "{\"vnstat_rx\":\"$RX\",\"vnstat_tx\":\"$TX\",\"v2ray_up\":\"0\",\"v2ray_down\":\"0\"}"
  sleep 30
done
