#!/bin/sh
#https://github.com/hongdou9022/ddns-script
#Based on https://github.com/kkkgo/dnspod-ddns-with-bashshell modification

#CONF START
API_ID=
API_Token=
domain=
DEV="ppp0"
#CONF END
#. /etc/profile
#date
IPREX='([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
ipcmd="ip addr show";type ip >/dev/null 2>&1||ipcmd="ifconfig"
DEVIP=$($ipcmd $DEV|grep -Eo "$IPREX"|head -n1)
if (echo $DEVIP |grep -qEvo "$IPREX");then
DEVIP="Get $DOMAIN DEVIP Failed."
fi
echo "[DEV IP]:$DEVIP"
dnscmd="nslookup";type nslookup >/dev/null 2>&1||dnscmd="ping -c1"
DNSTEST=$($dnscmd $domain)
if [ "$?" != 0 ]&&[ "$dnscmd" == "nslookup" ]||(echo $DNSTEST |grep -qEvo "$IPREX");then
DNSIP="Get $domain DNS Failed."
else 
DNSIP=$(echo $DNSTEST|grep -Eo "$IPREX"|tail -n1)
fi
echo "[DNS IP]:$DNSIP"
if [ "$DNSIP" == "$DEVIP" ];then
echo "IP SAME IN DNS,SKIP UPDATE."
exit
fi

token="login_token=${API_ID},${API_Token}&lang=en&format=json&domain=${domain}"
Record="$(curl -4 -k -s -X POST https://dnsapi.cn/Record.List -d "${token}&record_type=A")"
code="$(echo ${Record#*\"code\":}|cut -d'"' -f2)"
if [ "$code" != "1" ];then
error_msg=$(echo ${Record#*message\":}|cut -d'"' -f2)
error_msg="${error_msg}, code=${code}"
echo $error_msg
logger -t "[dnspod ddns]" "${error_msg}"
exit
fi

records_num=$(echo ${Record#*\"records_num\":}|cut -d'"' -f2)
records=$(echo ${Record#*\"records\":})

for i in $(seq 1 $records_num)
do
host=$(echo ${records#*\"name\":}|cut -d'"' -f2)
ip=$(echo ${records#*\"value\":}|cut -d'"' -f2)
if [ "$ip" != "$DEVIP" ];then
record_id=$(echo ${records#*\"id\":}|cut -d'"' -f2)
record_line_id=$(echo ${records#*\"line_id\":}|cut -d'"' -f2)

ddns="$(curl -4 -k -s -X POST https://dnsapi.cn/Record.Ddns -d "${token}&sub_domain=${host}&record_id=${record_id}&record_line_id=${record_line_id}&value=$DEVIP")"
ddns_result="$(echo ${ddns#*message\":}|cut -d'"' -f2)"
result="${host} up result:$ddns_result. ip: ${DEVIP}"
else
result="${host} ip is already ${ip}, skip."
fi
echo $result                                          
logger -t "[dnspod ddns]" "$result"

records=$(echo ${records#*\}})
done

