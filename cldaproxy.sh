#!/bin/bash
echo "CLDAProxy v1.0
@bitsadmin - https://github.com/bitsadmin/lofl"

bn=$(basename $0)
usage="\nConvert CLDAP (UDP) traffic to LDAP (TCP)

Usage: $bn <domain> [dc_ip]

Parameters:
  domain:    Domain name to resolve and use to proxy to
  dc_ip:     Use explicit server IP instead of deriving it from the domain

Examples:
  Proxy CLDAP to LDAP for domain ad.bitsadmin.com
  $bn ad.bitsadmin.com

  Proxy CLDAP to LDAP making use of DC 10.0.10.10
  $bn ad.bitsadmin.com 10.0.10.10"

# Function to remove PREROUTING rules
function remove_rules {
  echo -e "\nReceived SIGINT.\nShutting down proxy and removing PREROUTING rules"
  for ip in "${ips[@]}"; do
    sudo iptables -t nat -D PREROUTING -d "$ip" -p udp --dport 389 -j REDIRECT --to-port $port
  done
}

# Register trap for SIGINT signal (Ctrl+C)
trap 'remove_rules; exit 1' SIGINT

domain="$1"
dc_ip="$2"

# Check for mandatory positional parameter
if [[ -z $domain ]]; then
    echo -e "$usage" >&2
    exit 1
fi

# Check if socat binary exists
if ! command -v socat &> /dev/null; then
    echo -e "\nsocat binary not found. Please install socat." >&2
    exit 1
fi

# Check if running as root or sudo
if [ "$EUID" -ne 0 ]
then
    echo -e "\nPlease run as root or with sudo" >&2
    exit 1
fi

# Collect LDAP servers
echo -e "\nPerforming lookup of domain $domain..."
output=$(dig +short -t SRV _ldap._tcp.dc._msdcs.$domain)

if [ -z "$output" ]; then
    echo -e "\nNo records found. Is the DNS resolution working?"
    exit 1
fi

# Iterate over returned LDAP servers
ips=()
while IFS= read -r line; do
  # Extract hostname
  hostname=$(echo "$line" | awk '{print $NF}')

  # Resolve hostnames
  ip=$(dig +short $hostname)
  if [[ ! " ${ips[@]} " =~ " ${ip} " ]]; then
    ips+=("$ip")
  fi
done <<< "$output"

# Summarize LDAP server IPs
if [[ ${#ips[@]} -eq 0 ]]; then
  echo "No IP addresses found for domain $domain"
  exit 1
else
  echo "Found IPs:"
  for ip in "${ips[@]}"
  do
    echo "- $ip"
  done
fi

# Check available port
port=11389
while ss -lnu "sport = :$port" | grep ":$port" > /dev/null; do
  ((port+=1000))
done
echo -e "\nUsing port $port/UDP"

# Execute PREROUTING command for each IP address
echo -e "\nCreating PREROUTING rules:"
for ip in "${ips[@]}"; do
  echo "- $ip"
  iptables -t nat -A PREROUTING -d "$ip" -p udp --dport 389 -j REDIRECT --to-port $port
done

# Determine DC IP
if [[ -z "$dc_ip" ]]; then
  dc_ip="${ips[0]}"
fi

# Start socat for CLDAP to LDAP conversion
echo -e "\nStarting socat to proxy traffic to $dc_ip"
while true
do
	socat -v -s UDP-LISTEN:$port,fork,reuseaddr TCP:$dc_ip:389 2>&1 | while read line; do
	  if [[ "$line" =~ [\<\>]\ ([0-9 :./]+)\ length=[0-9]+\ from=[0-9]+\ to=[0-9]+ ]]; then
		echo "${BASH_REMATCH[0]}"
	  fi
	done
done

# Remove PREROUTING rules
remove_rules