#!/bin/sh
# CRONTAB
#* * * * * sleep 5; /tmp/home/root/generate_files.sh

#############################
# /tmp/dhcp_clients_mac.txt #
#############################
if [ -f /tmp/dhcp_clients_mac.txt ]; then
	cp -f /tmp/dhcp_clients_mac.txt /tmp/dhcp_clients_mac_tmp.txt
fi
cat /var/lib/misc/dnsmasq.leases | awk '{print ""$2" "$3" "$4""}' | grep -v '*' >> /tmp/dhcp_clients_mac_tmp.txt
cat /tmp/dhcp_clients_mac_tmp.txt | sort -u > /tmp/dhcp_clients_mac.txt
rm -f /tmp/dhcp_clients_mac_tmp.txt

########################
# /tmp/client_list.txt #
########################
if [ -f /tmp/client_list.txt ]; then
	cp -f /tmp/client_list.txt /tmp/client_list_tmp.txt
fi
OLDIFS=$IFS
IFS="<"
for CLIENT_ENTRY in $(nvram get custom_clientlist); do
	if [ "$CLIENT_ENTRY" = "" ]; then
		continue
	fi
	CLIENT_MAC=`echo "$CLIENT_ENTRY" | cut -d ">" -f1`
	CLIENT_HOSTNAME=`echo "$CLIENT_ENTRY" | cut -d ">" -f2`
	if [ "$CLIENT_HOSTNAME" != "" ]; then
		echo "$CLIENT_MAC $CLIENT_HOSTNAME" >> /tmp/client_list_tmp.txt
    fi
done
cat /tmp/client_list_tmp.txt | sort -u > /tmp/client_list.txt
rm -f /tmp/client_list_tmp.txt