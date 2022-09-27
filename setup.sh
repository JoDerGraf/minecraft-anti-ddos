#!/bin/bash


#      __   __               _                  
#  ___/ /__/ /__  ___   ____(_)__  ___  ___ ____
# / _  / _  / _ \(_-<  / __/ / _ \/ _ \/ -_) __/
# \_,_/\_,_/\___/___/ /_/ /_/ .__/ .__/\__/_/   
#                          /_/  /_/             
#
# created by oqo0 | 2022 
# 
# This script is free and open for any use and distribution. It is recommended to adjust the following
# parameters for yourself in order to achieve the best protection quality. This script has been tested
# on servers with hundreds of regular players. If you encounter any problems please create an issue on
# project's Github: https://github.com/oqo0/minecraft-anti-ddos
# 
# It is also quite important to note that if your hosting provider does not have DDOS protection, then
# this script will be practically useless.


# Block dangerous activity
#
# These rules are supposed to block invalid \ dangerous traffic from users.
# Not recommended to remove any rules from here.

# block invalid packets
iptables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP

# block xmas packets (kamikaze packets)
iptables -t mangle -A PREROUTING -p tcp -m tcp --tcp-flags ALL ALL -j DROP

# block null packets
iptables -t mangle -A PREROUTING -p tcp -m tcp --tcp-flags ALL NONE -j DROP 

# block not syn packets
iptables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

# block uncommon MMS values
iptables -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP

# block all icmp packets
iptables -t mangle -A PREROUTING -p icmp -j DROP

# drop fragments in all chains
iptables -t mangle -A PREROUTING -f -j DROP

# limit rst packets
iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP

# block packets with bogus tcp flags
iptables -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
iptables -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
iptables -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
iptables -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
iptables -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ALL ALL -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ALL NONE -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
iptables -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# block spoofed packets
iptables -A PREROUTING -s 224.0.0.0/3 -j DROP
iptables -A PREROUTING -s 169.254.0.0/16 -j DROP
iptables -A PREROUTING -s 172.16.0.0/12 -j DROP
iptables -A PREROUTING -s 192.0.2.0/24 -j DROP
iptables -A PREROUTING -s 192.168.0.0/16 -j DROP
iptables -A PREROUTING -s 10.0.0.0/8 -j DROP
iptables -A PREROUTING -s 0.0.0.0/8 -j DROP
iptables -A PREROUTING -s 240.0.0.0/5 -j DROP
iptables -A PREROUTING -s 127.0.0.0/8 ! -i lo -j DROP


# Traffic protection
# 
# The main task of this section is to reduce the load on the server during peak loads.
# You can adjust some values.

# block port scan
sudo iptables -N anti-port-scan
sudo iptables -A anti-port-scan -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j RETURN
sudo iptables -A anti-port-scan -j DROP

# block hosts that have more than 10 established connections
iptables -A INPUT -p tcp -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset
# limits the new tcp connections that a client can establish per second
iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 10/s --limit-burst 5 -j ACCEPT 
iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP

# use synproxy on all ports
iptables -t raw -A PREROUTING -p tcp -m tcp --syn -j CT --notrack
iptables -A INPUT -p tcp -m tcp -m conntrack --ctstate INVALID,UNTRACKED -j SYNPROXY --sack-perm --timestamp --wscale 7 --mss 1460
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# protect ssh from brute-force
iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --update --seconds 120 --hitcount 30 -j DROP

# protect rcon from brute-force
# enter your rcon port or remove this if you don't use it
rcon_port=21000
iptables -A INPUT -p tcp --dport $rcon_port -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport $rcon_port -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 20 -j DROP


# Geo protection
# 
# You can use this section to whitelist traffic from specific countries \ regions.
# This option is disabled by default.
# It is recommended to enable after you change the list of countries to the desired one.

# enable geo protection
enable_geo_protection=false

# set your minecraft port
minecraft_port=25565

# whitelisted countries
whitelisted_countries="us,uk,fr"

# get country ip blocks
country_list="https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/"

# add whitelisted countries to an ipset
for ip in $(curl -L $country_list/{$whitelisted_countries}.cidr);
    do ipset -A county_whitelist $ip
done

# allow connections only from whitelisted countries
iptables -A INPUT -m set --match-set county_whitelist src -p tcp --dport $minecraft_port -j ACCEPT
iptables -A INPUT -p tcp --dport $minecraft_port -j DROP