#!/bin/bash
echo "Create Tunnel Interface v1.0
@bitsadmin - https://github.com/bitsadmin/lofl"

bn=$(basename $0)
usage="Usage: $bn [-d] INTERFACE [IPSUBNET]

Parameters:
  -d:        Delete the interface
  INTERFACE: Name of the interface to be created, for example tun1
  IPSUBNET:  IP address and subnet mask that will be assigned to the new interface.
             Noted down in CIDR notation, for example: 198.18.0.1/15

Examples:
  Create new tunnel interface tun1
  $bn tun1

  Create new tunnel interface tun1 with specific IP/subnet
  $bn tun1 198.18.0.1/15

  Delete tunnel interface tun1
  $bn -d tun1"
  
# Parse command-line options
delete_interface=false
while getopts ":d" opt; do
    case ${opt} in
        d)
            delete_interface=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

# Shift the parsed options
shift $((OPTIND -1))

# Check for mandatory positional parameter
if [[ -z $1 ]]; then
    echo -e "$usage" >&2
    exit 1
fi

# Collect interface name
tunnel=$1

# Validate IP subnet if specified and interface is not marked for deletion
ipsubnet=198.18.0.1/15
if ! $delete_interface && ! [[ -z $2 ]]; then
    ipsubnet=$2
    if ! [[ "$ipsubnet" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
        echo "IP subnet \"$2\" is not a valid CIDR notation" >&2
        exit 1
    fi
fi

# Check if running as root or sudo
if [ "$EUID" -ne 0 ]
then
    echo "Please run as root or with sudo" >&2
    exit 1
fi

# Check if tunnel interface exists
if ip link show $tunnel &> /dev/null; then
    tun_exists=true
else
    tun_exists=false
fi

if $tun_exists; then
    if ! $delete_interface; then
        echo "Interface \"$tunnel\" already exists" >&2
        exit 1
    fi
else
    if $delete_interface; then
        echo "Interface \"$tunnel\" does not exist" >&2
        exit 1
    fi
fi

# Delete tunnel interface if -d is specified
if $delete_interface; then
    ip link delete $tunnel
    if [ $? -ne 0 ]; then
        echo "Error deleting interface \"$tunnel\"" >&2
        exit 1
    fi
    
    echo "Deletion of interface \"$tunnel\" successful!"
    exit 0
fi

# Create tunnel interface
echo "Creating tunnel interface $tunnel"
ip tuntap add mode tun dev $tunnel
if [ $? -ne 0 ]; then
    echo "Error creating interface" >&2
    exit 1
fi

# Assigning IP/subnet
echo "Assigning IP address/subnet $ipsubnet to $tunnel"
ip address add $ipsubnet dev $tunnel
if [ $? -ne 0 ]; then
    echo "Error assigning IP to interface" >&2
    exit 1
else
    echo "Tunnel interface creation successful!"
fi
