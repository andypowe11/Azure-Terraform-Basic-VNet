#!/bin/sh
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1
touch /tmp/ipforwarding
