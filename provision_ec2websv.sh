#!/bin/bash

usage(){
    echo "Usage: ec2_provision.sh <a10 IP address> <service group> <username> <password>"
    exit 1
    }

[ "$#" -eq 0 ] && usage >&2

a10_ip=$1
service_group=$2
username=$3
password=$4
url="https://$a10_ip/services/rest/V2/"

# TLSv1と証明書チェックをスキップするためのオプション
cmd_options='--tlsv1.0 --insecure'

# セッションIDの取得
session_id=`curl -v $cmd_options $url \
 -d method=authenticate \
 -d username=admin \
 -d password=a10 | \
 sed -n -e 's/.*<session_id>\(.*\)<\/session_id>.*/\1/p'`

#自分のプライベートIPアドレス取得
my_ip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
my_instanceid=`curl http://169.254.169.254/latest/meta-data/instance-id`

# サーバ登録
curl -v -X POST $cmd_options $url \
    -d session_id=$session_id \
    -d method=slb.server.create \
    -d name=$my_instanceid \
    -d host=$my_ip \
    -d status=1 \
    -d health_monitor=http_index \
    -d port_list=port1 \
    -d port1=port_num,protocol \
    -d port_num=80 \
    -d protocol=2

# サービスグループへメンバ登録
curl -v -X POST $cmd_options $url \
    -d session_id=$session_id \
    -d method=slb.service_group.member.create \
    -d name=$service_group \
    -d member=server,port \
    -d server=$my_ip \
    -d port=80


