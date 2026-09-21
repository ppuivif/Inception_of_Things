#!/bin/bash
set -e

IP=192.168.56.110

for host in app1.com app2.com app3.com; do
    if ! grep -qF "$host" /etc/hosts; then
        echo "$IP $host" | sudo tee -a /etc/hosts
    fi
done
