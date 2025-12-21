#!/bin/sh

/usr/sbin/sysctl -w net.inet.ip.forwarding=0
pfctl -a wireguard -F all
