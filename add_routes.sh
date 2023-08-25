#!/bin/bash
echo "Add Routes v1.0
@bitsadmin - https://github.com/bitsadmin/lofl
"

bn=$(basename $0)
usage="Usage: $bn <subnet_file> <interface> [gateway_ip]

Parameters:
  subnet_file:  File containing list of subnets in CIDR notation
  interface:    Interface over which these interfaces must be tunneled
  gateway_ip:   Optional explicit gateway IP, by default 198.18.0.1

Examples:
  Route IPs from subnets.txt over tun1
  $bn subnets.txt tun1

Example subnet.txt contents
10.0.10.0/24
10.0.20.0/24
10.0.30.0/24
192.168.0.0/16
"

if [ $# -lt 2 ]; then
    echo -e "$usage" >&2
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run the script as root or using sudo."
    exit 1
fi

subnet_file="$1"
interface="$2"
gateway_ip="${3:-198.18.0.1}"

while IFS= read -r subnet; do
    if [[ $subnet == \#* ]]; then
        continue
    fi

    command="sudo ip route add $subnet via $gateway_ip dev $interface"
    echo "Adding route: $command"
    eval "$command"
done < "$subnet_file"