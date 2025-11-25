#!/usr/bin/env bash
set -euo pipefail

echo "# DNS" > checks/dns.txt
{
  host app01.dc.local
  host app02.dc.local
  host proxy01.dc.local
} >> checks/dns.txt 2>&1 || true

echo "# Backends from proxy01" > checks/backend.txt
{
  curl -s http://app01.dc.local:8080/
  curl -s http://app02.dc.local:8080/
} >> checks/backend.txt

echo "# Round-robin via proxy01" > checks/proxy-roundrobin.txt
for i in {1..10}; do curl -s http://proxy01.dc.local/; done >> checks/proxy-roundrobin.txt

echo "# Access log sample (first 10 lines)" > checks/access-sample.json
sudo head -n 10 /var/log/nginx/access.json >> checks/access-sample.json || true

# Failover
echo "# Failover test" > checks/failover.txt
echo "Stopping app02..." | tee -a checks/failover.txt
sudo systemctl stop simple-backend@app02
for i in {1..5}; do
  out="$(curl -s http://proxy01.dc.local/)"
  echo "$out" | tee -a checks/failover.txt
  sleep 0.3
done
echo "--- last 10 access log lines during failover ---" >> checks/failover.txt
sudo tail -n 10 /var/log/nginx/access.json >> checks/failover.txt || true

echo "Starting app02..." | tee -a checks/failover.txt
sudo systemctl start simple-backend@app02
sleep 2
for i in {1..6}; do
  curl -s http://proxy01.dc.local/ | tee -a checks/failover.txt
  sleep 0.3
done
echo "--- last 10 access log lines after recovery ---" >> checks/failover.txt
sudo tail -n 10 /var/log/nginx/access.json >> checks/failover.txt || true

echo "Done. See checks/ directory."