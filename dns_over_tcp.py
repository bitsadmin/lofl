#!/usr/bin/env python
import sys
import threading
import socketserver
import time
import re
import argparse
from struct import pack,unpack
from threading import Lock
s_print_lock = Lock()

VERSION = 1.0


# Check dnslib library
try:
    from dnslib import *
except ImportError:
    sys.exit("Make sure to have 'dnslib' installed.")


# Settings
dns_server = ('127.0.0.1', 5353)
whitelist = []
verbose = False


def socket_receive(sock, num_octets):
    response = b""
    read_octets = 0
    
    while (read_octets < num_octets):
        chunk = sock.recv(num_octets - read_octets)
        chunk_len = len(chunk)
        
        if chunk_len == 0:
            return b""
        
        read_octets += chunk_len
        response += chunk
    
    return response


class TCPForwarder(socketserver.BaseRequestHandler):
    def handle(self):
        # Show forward in output
        now = time.strftime('%Y-%m-%d %H:%M:%S')
        client_ip = self.client_address[0]
        client_port = '%d' % self.client_address[1]
        padding = 21 - len(client_ip) - len(client_port)
        info = '%s | TCP: %s:%s | TCP forward' % (now, client_ip, client_port.ljust(padding + len(client_port)))
        s_print(info)

        # Create TCP connection to DNS server
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(dns_server)

        # Receive DNS request from client
        data = self.request.recv(1024)

        # Forward it to the DNS server
        s.send(data)

        # Receive response from DNS server
        response = s.recv(1024)

        # Forward response from DNS server to client
        self.request.send(response)

        # Close TCP sockets
        s.close()
        self.request.close()


class UDPToTCPForwarder(socketserver.BaseRequestHandler):
    def handle(self):
        now = time.strftime('%Y-%m-%d %H:%M:%S')
        data = self.request[0]
        request = None
        try:
            request = DNSRecord.parse(data)
        except Exception as e:
            s_print('%s Exception parsing record' % now)
            s_print('data: %s' % data)
            s_print('exception: %s' % str(e))
            forward_over_tcp = True

        if request:
            # Collect information about request
            client_ip = self.client_address[0]
            client_port = '%d' % self.client_address[1]
            padding = 21 - len(client_ip) - len(client_port)

            # If there are multiple questions in a single DNS request, if one of the questions contains a
            # question from the whitelist, force the full request over TCP
            forward_over_tcp = False
            for question in request.questions:
                if forward_over_tcp:
                    break

                # Determine requested domain
                query = '.'.join(x.decode() for x in question.qname.label)

                # Only forward_over_tcp requests in the whitelist
                forward_over_tcp = False
                for entry in whitelist:
                    if query.lower().endswith('.' + entry) or query.lower() == entry:
                        forward_over_tcp = True
                        break

        # Forward UDP DNS request over TCP
        if forward_over_tcp:
            # Show request in output
            s_print('%s | UDP: %s:%s | TCP convert | %s' % (now, client_ip, client_port.ljust(padding + len(client_port)), query))
            
            # Construct TCP packet
            # The query in this packet needs to be prefixed by the size of the query
            packet_len = pack("!H", len(data))
            data_tcp = packet_len + data
            
            # Connect to DNS server over TCP
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(dns_server)
            
            # Send data
            sock.send(data_tcp)
            
            # Receive length fo response packet
            length = socket_receive(sock, 2)
            
            response = None
            if (len(length) == 2):
                resp_len, = unpack('!H', length)
            
                # Obtain DNS response
                response = socket_receive(sock, resp_len)
            else:
                s_print('%s Error: Not able to connect to upstream server' % now)
            
            # Close socket
            sock.close()

            # Forward back over UDP
            if response:
                self.request[1].sendto(response, self.client_address)

        # Just forward UDP DNS query
        else:
            if verbose:
                # Show request in output
                info = '%s | UDP: %s:%s | UDP answer  | %s' % (now, client_ip, client_port.ljust(padding + len(client_port)), query)
                s_print(info)

            # Prepare UDP connection to DNS server
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

            # Send data
            s.sendto(data, dns_server)

            # Receive response
            response = s.recv(1024)

            # Forward response from DNS server to client
            self.request[1].sendto(response, self.client_address)
            
            # Close client socket
            s.close()


def get_dnsmasq_whitelist():
    p = '/etc/dnsmasq.conf'

    # Return if dnsmasq config does not exist
    if not os.path.exists(p):
        print('File "%s" does not exist' % p)
        return []

    # Collect explicitly specified servers
    regex_servers = re.compile(r'^server=\/(.*)/.*', re.MULTILINE | re.IGNORECASE)
    with open(p, 'r') as f:
        dnsmasq_conf = f.read()
    matches = regex_servers.findall(dnsmasq_conf)

    # Return unique matches
    return sorted([m.lower() for m in set(matches)])


# Thread safe print function
def s_print(*a, **b):
    with s_print_lock:
        print(*a, **b)


def main(args):
    # Settings
    global verbose, dns_server, whitelist
    # Verbosity
    verbose = args.verbose
    print('Verbosity: %s' % ('Display all DNS requests' if verbose else 'Display only UDP->TCP converted DNS requests (default)'))
    # Upstream DNS server
    s_server, s_port = args.dns_server.split(':')
    dns_server = (s_server, int(s_port))
    print('Upstream DNS server: %s' % args.dns_server)
    # Dnsmasq settings
    if not args.ignore_dnsmasq:
        whitelist = get_dnsmasq_whitelist()
        print('Whitelist:\n%s' % '\n'.join('- %s' % x for x in whitelist))
    print()
    
    # DNS UDP to TCP forwarder
    print('[+] Starting DNS UDP to TCP forwarder on port 53/UDP')
    udp_to_tcp_forwarder = socketserver.ThreadingUDPServer(('', 53), UDPToTCPForwarder)
    dns_thread = threading.Thread(target=udp_to_tcp_forwarder.serve_forever)
    dns_thread.daemon = True
    dns_thread.start()

    # TCP forwarder
    print('[+] Starting DNS TCP forwarder on port 53/TCP')
    tcp_forwarder = socketserver.ThreadingTCPServer(('', 53), TCPForwarder)
    tcp_thread = threading.Thread(target=tcp_forwarder.serve_forever)
    tcp_thread.daemon = True
    tcp_thread.start()

    # Run till keyboard interrupt
    print('[+] Ready for queries\n')
    print('Timestamp           | Src Protocol IP:Port        | Action      | Query')
    print('--------------------+-----------------------------+-------------+-----------------------')
    try:
        while True:
            time.sleep(1)
            sys.stderr.flush()
            sys.stdout.flush()

    except KeyboardInterrupt:
        print('\n[+] Keyboard interrupt received')
        pass

    finally:
        print('[+] Shutting down DNS UDP to TCP forwarder on port 53/UDP')
        udp_to_tcp_forwarder.shutdown()
        print('[+] Shutting down DNS TCP forwarder on port 53/TCP')
        tcp_forwarder.shutdown()
        tcp_forwarder.server_close()
        print('[+] Closing down')


def getargs():
    parser = argparse.ArgumentParser(
        description='Selectively forward UDP DNS requests over TCP'
    )

    parser.add_argument('-v', '--verbose', action='store_true', help='By default shows requests to hosts specified in the dnsmasq.conf; verbose shows all DNS requests')
    parser.add_argument('-i', '--ignore', action='store_true', dest='ignore_dnsmasq', help='Ignore DNSMasq configuration')
    parser.add_argument('-s', '--server', action='store', default='127.0.0.1:5353', nargs='?', dest='dns_server', help='Specify upstream DNS server, default 127.0.0.1:5353')

    return parser.parse_args()


if __name__ == '__main__':
    print('DNSOverTCP v%.2f ( https://github.com/bitsadmin/lofl )\n' % VERSION)
    main(getargs())
