#!/bin/bash
echo "Create iptables NAT v1.0
@bitsadmin - https://github.com/bitsadmin/lofl
"

bn=$(basename $0)
usage="Usage: $bn [-d] [-f] INPUT OUTPUT

Parameters:
  -d:       Delete the iptables rule
  -f:       Skip user confirmation prompt
  INPUT:    Input interface
  OUTPUT:   Output interface

Examples:
  Create NAT from ens36 to tun1
  $bn ens36 tun1

  Delete NAT from ens36 to tun1
  $bn -d ens36 tun1

  Delete NAT from ens36 to tun1 without prompt
  $bn -d -f ens36 tun1"

# Parse command-line options
delete_nat=false
force=false
while getopts ":df" opt; do
    case ${opt} in
        d)
            delete_nat=true
            ;;
            f)
            force=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Shift the parsed options
shift $((OPTIND -1))

# Return usage if no sufficient parameters are provided
if [[ -z $2 ]]; then
    echo -e "$usage" >&2
    exit 1
fi

# Check for INPUT interface
input=$1
if ! $delete_nat && ! ip link show $input &> /dev/null; then
    echo "INPUT interface \"$input\" does not exist"
    exit 1
fi

# Check for OUTPUT interface
output=$2
if ! $delete_nat && ! ip link show $output &> /dev/null; then
    echo "OUTPUT interface \"$output\" does not exist"
    exit 1
fi

# Check if running as root or sudo
if [ "$EUID" -ne 0 ]
then
    echo "Please run as root or with sudo" >&2
    exit 1
fi

# Check for each rule whether it exists
iptables -t nat -C POSTROUTING -o $output -j MASQUERADE >/dev/null 2>&1
rule1=$?
iptables -C FORWARD -i $output -o $input -m state --state RELATED,ESTABLISHED -j ACCEPT >/dev/null 2>&1
rule2=$?
iptables -C FORWARD -i $input -o $output -j ACCEPT >/dev/null 2>&1
rule3=$?

# Display actions to be performed
if $delete_nat; then
    echo "Going to delete rules:"
    cmd='D'
else
    echo "Going to add rules:"
    cmd='A'
fi

echo "- Rule 1: -t nat -$cmd POSTROUTING -o $output -j MASQUERADE"
echo "- Rule 2: -$cmd FORWARD -i $output -o $input -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "- Rule 3: -$cmd FORWARD -i $input -o $output -j ACCEPT"
echo

# Check with user if force flag is not specified
if ! $force; then
    read -p "Press Enter to continue..."
    echo
fi

# Perform iptables modifications
echo "Performing iptables updates:"
if $delete_nat; then
    if [ $rule1 -eq 0 ]; then
        echo "- Deleting rule 1"
        iptables -D FORWARD -i $input -o $output -j ACCEPT
    else
        echo "- Rule 1 does not exist" >&2
    fi
    
    if [ $rule2 -eq 0 ]; then
        echo "- Deleting rule 2"
        iptables -D FORWARD -i $output -o $input -m state --state RELATED,ESTABLISHED -j ACCEPT
    else
        echo "- Rule 2 does not exist" >&2
    fi

    if [ $rule3 -eq 0 ]; then
        echo "- Deleting rule 3"
        iptables -t nat -D POSTROUTING -o $output -j MASQUERADE
    else
        echo "- Rule 3 does not exist" >&2
    fi
else
    if [ $rule1 -eq 1 ]; then
        echo "- Adding rule 1"
        iptables -t nat -A POSTROUTING -o $output -j MASQUERADE
    else
        echo "- Rule 1 already exists"
    fi

    if [ $rule2 -eq 1 ]; then
        echo "- Adding rule 2"
        iptables -A FORWARD -i $output -o $input -m state --state RELATED,ESTABLISHED -j ACCEPT
    else
        echo "- Rule 2 already exists"
    fi

    if [ $rule3 -eq 1 ]; then
        echo "- Adding rule 3"
        iptables -A FORWARD -i $input -o $output -j ACCEPT
    else
        echo "- Rule 3 already exists"
    fi
fi
