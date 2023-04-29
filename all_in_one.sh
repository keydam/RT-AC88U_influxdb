#!/bin/sh
# CRONTAB
#* * * * * /tmp/home/root/all_in_one.sh
#* * * * * sleep 15; /tmp/home/root/all_in_one.sh
#* * * * * sleep 30; /tmp/home/root/all_in_one.sh
#* * * * * sleep 45; /tmp/home/root/all_in_one.sh

# InfluxDB
INFLUX_PROTOCOL="http"
INFLUX_HOST="192.168.1.114"
INFLUX_PORT="8086"
INFLUX_DATABASE="telegraf"
INFLUX_USERNAME="telegraf"
INFLUX_PASSWORD="telegr@f"

# Router
ROUTER="RT-AC88U"

# Date
CURRENT_DATE=`date +%s`

# Fichier
rm -f /tmp/data.influx
rm -f /tmp/global.tmp
rm -f /tmp/traffic.tmp

#######
# CPU #
#######
PROCESS_TOTAL=`ps | wc -l`
TOP_OUTPUT=`top -bn1 | head -3`
USR=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $2}' | sed 's/%//g'`
SYS=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $4}' | sed 's/%//g'`
NICE=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $6}' | sed 's/%//g'`
IDLE=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $8}' | sed 's/%//g'`
IO=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $10}' | sed 's/%//g'`
IRQ=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $12}' | sed 's/%//g'`
SIRQ=`echo "$TOP_OUTPUT" | awk '/CPU/ {print $14}' | sed 's/%//g'`
LOAD_1=`echo "$TOP_OUTPUT" | awk '/Load average:/ {print $3}' | sed 's/%//g'`
LOAD_5=`echo "$TOP_OUTPUT" | awk '/Load average:/ {print $4}' | sed 's/%//g'`
LOAD_15=`echo "$TOP_OUTPUT" | awk '/Load average:/ {print $5}' | sed 's/%//g'`
echo "router.cpu,host=${ROUTER} usr=${USR},sys=${SYS},nice=${NICE},idle=${IDLE},io=${IO},irq=${IRQ},sirq=${SIRQ},load1=${LOAD_1},load5=${LOAD_5},load15=${LOAD_15},processes=${PROCESS_TOTAL} ${CURRENT_DATE}000000000" >> /tmp/data.influx

##########
# MEMORY #
##########
TOTAL=`free -h | grep "Mem:" | awk '{print $2}'`
USED_KB=`echo "$TOP_OUTPUT" | awk '/Mem/ {print $2}' | sed 's/K//g'`
FREE_KB=`echo "$TOP_OUTPUT" | awk '/Mem/ {print $4}' | sed 's/K//g'`
SHARED_KB=`echo "$TOP_OUTPUT" | awk '/Mem/ {print $6}' | sed 's/K//g'`
BUFFER_KB=`echo "$TOP_OUTPUT" | awk '/Mem/ {print $8}' | sed 's/K//g'`
CACHED_KB=`echo "$TOP_OUTPUT" | awk '/Mem/ {print $10}' | sed 's/K//g'`
echo "router.mem,host=${ROUTER} total=${TOTAL},used_kb=${USED_KB},free_kb=${FREE_KB},shrd_kb=${SHARED_KB},buff_kb=${BUFFER_KB},cached_kb=${CACHED_KB} ${CURRENT_DATE}000000000" >> /tmp/data.influx

###############
# TEMPERATURE #
###############
TEMP_24=`wl -i eth1 phy_tempsense | awk '{ print $1 * .5 + 20 }'`
TEMP_50=`wl -i eth2 phy_tempsense | awk '{ print $1 * .5 + 20 }'`
TEMP_CPU=`head -1 /proc/dmu/temperature | awk -v RS='[0-9]+' '$0=RT'` 
echo "router.temp,host=${ROUTER} temp_24=${TEMP_24},temp_50=${TEMP_50},temp_cpu=${TEMP_CPU} ${CURRENT_DATE}000000000" >> /tmp/data.influx

###############
# CONNECTIONS #
###############
ACTIVE_DHCP_LEASES=`cat /var/lib/misc/dnsmasq.leases | wc -l`
CONNECTED_CLIENTS=`arp -a -n | awk '$4!="<incomplete>"' | wc -l`
WIFI_24=`wl -i eth1 assoclist | awk '{print $2}' | wc -l`
WIFI_50=`wl -i eth2 assoclist | awk '{print $2}' | wc -l`
echo "router.connections,host=${ROUTER},type=connections dhcp_leases=${ACTIVE_DHCP_LEASES},connected_clients=${CONNECTED_CLIENTS},wifi_24=${WIFI_24},wifi_5=${WIFI_50} ${CURRENT_DATE}000000000" >> /tmp/data.influx

##########
# UPTIME #
##########
UPTIME=`cat /proc/uptime | cut -d' ' -f1`
echo "router.uptime,host=${ROUTER} uptime=$UPTIME ${CURRENT_DATE}000000000" >> /tmp/data.influx

#############
# BANDWIDTH #
#############
iptables -N RRDIPT2 > /dev/null 2>&1
iptables -L FORWARD -n | grep RRDIPT2 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	iptables -L FORWARD -n | grep "RRDIPT2" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		iptables -D FORWARD -j RRDIPT2 > /dev/null 2>&1
	fi
	iptables -I FORWARD -j RRDIPT2 > /dev/null 2>&1
fi
iptables -nvL RRDIPT2 | grep eth0.*br0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	iptables -I RRDIPT2 -i eth0 -o br0 -j RETURN > /dev/null 2>&1
fi
iptables -nvL RRDIPT2 | grep br0.*eth0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	iptables -I RRDIPT2 -i br0 -o eth0 -j RETURN > /dev/null 2>&1
fi
iptables -N RRDIPT > /dev/null 2>&1
iptables -L FORWARD -n | grep RRDIPT[^2] > /dev/null 2>&1
if [ $? -ne 0 ]; then
	iptables -L FORWARD -n | grep "RRDIPT" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		iptables -D FORWARD -j RRDIPT > /dev/null 2>&1
	fi
	iptables -I FORWARD -j RRDIPT > /dev/null 2>&1
fi
grep br0 /proc/net/arp | while read IP TYPE FLAGS MAC MASK IFACE; do
	iptables -nL RRDIPT | grep "${IP} " > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		iptables -I RRDIPT -d ${IP} -j RETURN > /dev/null 2>&1
		iptables -I RRDIPT -s ${IP} -j RETURN > /dev/null 2>&1
	fi
done


iptables -L RRDIPT -vnxZ -t filter > /tmp/traffic.tmp
iptables -L RRDIPT2 -vnxZ -t filter > /tmp/global.tmp
grep -Ev "0x0|IP" /proc/net/arp  | while read IP TYPE FLAGS MAC MASK IFACE; do
	IN=0
	OUT=0
	grep "${IP} " /tmp/traffic.tmp | while read PKTS BYTES TARGET PROT OPT IFIN IFOUT SRC DST; do
		if [ "${DST}" = "${IP}" ]; then
			IN=${BYTES}
		fi
		if [ "${SRC}" = "${IP}" ]; then
			OUT=${BYTES}
		fi
		CLIENT_LC=`echo "${MAC}" | tr '[:upper:]' '[:lower:]'`
		IP=`grep ${CLIENT_LC} /proc/net/arp | awk '{print $1}' | head -1`
		HOST=`grep -i ${CLIENT_LC} /tmp/dhcp_clients_mac.txt | awk '{print $3}' | head -1`
		if [ -z "${IP}" ]; then
			IP=${MAC}
		fi
		if [ "${HOST}" = "" ]; then
			HOST=`grep -i ${CLIENT_LC} /tmp/client_list.txt | head -1 | awk '{print $1}'`
		fi	
		if [ -z "${HOST}" ]; then
			HOST=${MAC}
		fi
		if [[ -n "${IP}" ]] && [[ -n "${HOST}" ]] && [[ -n "${MAC}" ]]; then
			echo "router.traffic,HOST=${ROUTER},mac=$MAC,ip=${IP},hostname=${HOST} inBytes=${IN},outBytes=${OUT} ${CURRENT_DATE}000000000" >> /tmp/data.influx
		fi
	done
done

IN=0
OUT=0
grep br0 /tmp/global.tmp | while read PKTS BYTES TARGET PROT OPT IFIN IFOUT SRC DST; do
	if [ "${IFIN}" = "br0" ]; then
		IN=${BYTES}
	fi
	if [ "${IFIN}" = "eth0" ]; then
		OUT=${BYTES}
	fi
	CLIENT_LC=`echo "${MAC}" | tr '[:upper:]' '[:lower:]'`
	IP=`grep ${CLIENT_LC} /proc/net/arp | awk '{print $1}' | head -1`
	HOST=`grep -i ${CLIENT_LC} /tmp/dhcp_clients_mac.txt | awk '{print $3}' | head -1`
	if [ -z "${IP}" ]; then
		IP=${MAC}
	fi
	if [ "${HOST}" = "" ]; then
		HOST=`grep -i ${CLIENT_LC} /tmp/client_list.txt | head -1 | awk '{print $1}'`
	fi	
	if [ -z "${HOST}" ]; then
		HOST=${MAC}
	fi
	if [[ -n "${IP}" ]] && [[ -n "${HOST}" ]] && [[ -n "${MAC}" ]]; then
		echo "router.traffic,host=${ROUTER},mac=${MAC},ip=${IP},hostname=${HOST} inBytes=${IN},outBytes=${OUT} ${CURRENT_DATE}000000000" >> /tmp/data.influx
	fi
done

###################
# UPLOAD INFLUXDB #
###################
CURL_RESPONSE=`curl -is -k -XPOST "${INFLUX_PROTOCOL}://${INFLUX_HOST}:${INFLUX_PORT}/write?db=${INFLUX_DATABASE}&u=${INFLUX_USERNAME}&p=${INFLUX_PASSWORD}" --data-binary @/tmp/data.influx`