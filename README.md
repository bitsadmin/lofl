# Living Off the Foreign Land
Scripts to setup and run the Living Off the Foreign Land (LOFL) attacker infrastructure. Refer to the following article at the BITSADMIN Blog for details on how to use the scripts in this repository.

## Living Off the Foreign Land: Using Windows as Attack Platform
* Part 1: Setup Linux VM for SOCKS routing - <https://blog.bitsadmin.com/living-off-the-foreign-land-windows-as-offensive-platform>
* Part 2: Configuring the Offensive Windows VM - <https://blog.bitsadmin.com/living-off-the-foreign-land-windows-as-offensive-platform-part-2>
* Part 3: Using Windows as Offensive Platform - <https://blog.bitsadmin.com/living-off-the-foreign-land-windows-as-offensive-platform-part-3>

## Scripts
| Name                                   | Description                                                                                                                                                  |
|----------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`dns_over_tcp.py`](#dns_over_tcppy)   | DNS server which based on the dnsmasq configuration file, selectively converts UDP DNS requests to TCP DNS requests so they can be sent over SOCKS4          |
| [`cldaproxy.sh`](#cldaproxysh)         | Script which makes use of `iptables` and `socat` to transform Connectionless LDAP (CLDAP/UDP) requests in to LDAP (TCP) so they can be forwarded over SOCKS4 |
| [`create_tun.sh`](#create_tunsh)       | Helper script to create a new `tun` interface and configure its IP                                                                                           |
| [`iptables_nat.sh`](#iptables_natsh)   | Helper script to add `iptables` NAT rules to interfaces                                                                                                      |
| [`add_routes.sh`](#add_routessh)       | Helper script to add routes over a certain interface                                                                                                         |
| [`CollectCerts.ps1`](#collectcertsps1) | Connects to a TLS port and saves the server certificate(s) as .crt files to disk                                                                             |
| [`DisableWindowsDefender.ps1`](#disablewindowsdefenderps1) | Mostly automates the [Pre-Install procedures of Mandiant's Commando VM repository](https://github.com/mandiant/commando-vm#pre-install-procedures) to disable Windows Defender on the Offensive Windows VM |

## dns\_over\_tcp.py
### Description
DNS server which based on the dnsmasq configuration file, selectively converts UDP DNS requests to TCP DNS requests so they can be sent over SOCKS4

### Usage
```
DNSOverTCP v1.00 ( https://github.com/bitsadmin/lofl )

usage: dns_over_tcp.py [-h] [-v] [-i] [-s [DNS_SERVER]]

Selectively forward UDP DNS requests over TCP

options:
  -h, --help            show this help message and exit
  -v, --verbose         By default shows requests to hosts specified in the dnsmasq.conf; verbose shows all DNS requests
  -i, --ignore          Ignore DNSMasq configuration
  -s [DNS_SERVER], --server [DNS_SERVER]
                        Specify upstream DNS server, default 127.0.0.1:5353
```

## cldaproxy.sh
### Description
Script which makes use of `iptables` and `socat` to transform Connectionless LDAP (CLDAP/UDP) requests in to LDAP (TCP) so they can be forwarded over SOCKS4

### Usage
```
CLDAProxy v1.0
@bitsadmin - https://github.com/bitsadmin/lofl

Convert CLDAP (UDP) traffic to LDAP (TCP)

Usage: cldaproxy.sh <domain> [dc_ip]

Parameters:
  domain:    Domain name to resolve and use to proxy to
  dc_ip:     Use explicit server IP instead of deriving it from the domain

Examples:
  Proxy CLDAP to LDAP for domain ad.bitsadmin.com
  cldaproxy.sh ad.bitsadmin.com

  Proxy CLDAP to LDAP making use of DC 10.0.10.10
  cldaproxy.sh ad.bitsadmin.com 10.0.10.10
```

## create\_tun.sh
### Description
Helper script to create a new `tun` interface and configure its IP

### Usage
```
Create Tun v1.0
@bitsadmin - https://github.com/bitsadmin/lofl

Usage: create_tun.sh [-d] INTERFACE [IPSUBNET]

Parameters:
  -d:        Delete the interface
  INTERFACE: Name of the interface to be created, for example tun1
  IPSUBNET:  IP address and subnet mask that will be assigned to the new interface.
             Noted down in CIDR notation, for example: 198.18.0.1/15

Examples:
  Create new tunnel interface tun1
  create_tun.sh tun1

  Create new tunnel interface tun1 with specific IP/subnet
  create_tun.sh tun1 198.18.0.1/15

  Delete tunnel interface tun1
  create_tun.sh -d tun1
```

## iptables\_nat.sh
### Description
Helper script to add `iptables` NAT rules to interfaces

### Usage
```
Create iptables NAT v1.0
@bitsadmin - https://github.com/bitsadmin/lofl

Usage: iptables_nat.sh [-d] [-f] INPUT OUTPUT

Parameters:
  -d:       Delete the iptables rule
  -f:       Skip user confirmation prompt
  INPUT:    Input interface
  OUTPUT:   Output interface

Examples:
  Create NAT from ens36 to tun1
  iptables_nat.sh ens36 tun1

  Delete NAT from ens36 to tun1
  iptables_nat.sh -d ens36 tun1

  Delete NAT from ens36 to tun1 without prompt
  iptables_nat.sh -d -f ens36 tun1
```

## add\_routes.sh
### Description
Helper script to add routes over a certain interface

### Usage
```
Add Routes v1.1
@bitsadmin - https://github.com/bitsadmin/lofl

Usage: add_routes.sh <subnet_file> <interface> [gateway_ip]

Parameters:
  subnet_file:  File containing list of subnets in CIDR notation
  interface:    Interface over which these interfaces must be tunneled
  gateway_ip:   Optional explicit gateway IP, by default 198.18.0.1

Examples:
  Route IPs from subnets.txt over tun1
  add_routes.sh subnets.txt tun1

Example subnet.txt contents
10.0.10.0/24    # Domain X
10.0.20.0/24    # Domain Y
10.0.30.0/24
192.168.0.0/16
```

## CollectCerts.ps1
### Description
Connects to a TLS port and saves the server certificate(s) as .crt files to disk

### Usage
```
NAME
    CollectCerts.ps1

SYNOPSIS
    This script connects to a TLS port and saves the server certificate(s) as `.crt` files to disk.

SYNTAX
    CollectCerts.ps1 [-Server] <Object> [[-Port] <Int32>] [<CommonParameters>]

DESCRIPTION
    The 'CollectCerts.ps1' script establishes a connection to the specified server using either the default port 636 (LDAPS) or alternatively a custom port can be specified.
```


## DisableWindowsDefender.ps1
### Description
Mostly automates the [Pre-Install procedures of Mandiant's Commando VM repository](https://github.com/mandiant/commando-vm#pre-install-procedures) to disable Windows Defender on the Offensive Windows VM.

### Usage
Simply right click the script and choose Run with PowerShell.

```
 -=[ Windows Defender Disable v1.1 ]=-


Fully disables Windows Defender in three reboots
by @bitsadmin - https://github.com/bitsadmin/lofl

[+] Tamper Protection is disabled
[+] Real-Time Protection is disabled
[+] Disabled Microsoft Defender Antivirus
[+] Disabled Cloud-Delivered Protection
[+] Disabled Automatic Sample Submission
[+] Systray Security Health icon is disabled
[+] Killed Systray Security Health icon
[+] Disabled task "Windows Defender Verification"
[+] Disabled task "Windows Defender Cleanup"
[+] Disabled task "Windows Defender Scheduled Scan"
[+] Disabled task "Windows Defender Cache Maintenance"
[+] Disabled Windows Defender scheduled tasks
[+] Cleanup
    [+] Re-enabling UAC
    [+] Unregistering script from automatic startup
[+] The final step is to boot into Safe Mode and disable the services/drivers related to Windows Defender
1. Reboot the machine in Safe Mode: Start -> Power -> Shift+Click on Reboot
   -> Troubleshoot -> Advanced options -> Startup Settings -> Restart
   -> Choose: '4) Enable Safe Mode'
2. Once booted in Safe Mode, launch PowerShell and execute the following oneliner:
   'Sense','WdBoot','WdFilter','WdNisDrv','WdNisSvc','WinDefend' | % { Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\$_ -Name Start -Value 4 -Verbose }
3. Reboot to Normal Mode and Windows Defender will be disabled!
4. Because disabling Windows Defender sometimes causes slow downs with software installations, make sure to also disable Smart App Control through either:
   - windowsdefender://SmartApp/
   - Searching the Settings for 'Smart App Control'
```
