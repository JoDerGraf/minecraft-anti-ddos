#!/bin/bash

ipset destroy country_whitelist
ipset -N -! country_whitelist hash:net maxelem 100000

# get country ip blocks
country_list="https://github.com/herrbischoff/country-ip-blocks/blob/master/ipv4/at.cidr"

# add whitelisted countries to an ipset
# countries from https://gist.github.com/oqo0/47a185af30c966a362dbdfebf3771400
for ip in $(curl -L $country_list/{de,uk,fr,es,ca,au,ch,it,pl}.cidr);
    do ipset -A country_whitelist $ip
done

# allow connections only from whitelisted countries
iptables -A INPUT -p tcp --dport 25565 -m set --match-set country_whitelist src -j ACCEPT
iptables -A INPUT -p tcp --dport 25565 --syn -j DROP
