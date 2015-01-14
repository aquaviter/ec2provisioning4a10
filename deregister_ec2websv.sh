#!/bin/bash

usage(){
    echo "Usage: deregister_ec2.sh <a10 IP address> <service group> <instance name> <username> <password>"
    exit 1
    }

[ "$#" -ne 5 ] && usage >&2

a10_ip=$1
service_group=$2
instance_name=$3
username=$4
password=$5
url="https://$a10_ip/services/rest/V2/"

# SQSのQueue URL
queue_url="https://ap-northeast-1.queue.amazonaws.com/640175474045/websvtermination"

# Queueのメッセージを取得
message=`aws sqs receive-message --queue-url=$queue_url --output=text | sed -n -e 's/.*{\(.*\)}.*/\1/p'`

# Queueにメッセージが無かったら終了
if [ -z "$message" ] then
    exit
fi

# メッセージからAutoscalingグループ名、LifecycleActionトークンとEC2InstanceIDを取得
ag_name=`echo $message | awk -F',' '{print $1}' | awk -F':' '{print $2'} | sed -e s/\"//g`
token=`echo $message | awk -F',' '{print $7}' | awk -F':' '{print $2'} | sed -e s/\"//g`
instanceid=`echo $message | awk -F',' '{print $8}' | awk -F':' '{print $2'} | sed -e s/\"//g`
lifecycle_name=`echo $message | awk -F',' '{print $9}' | awk -F':' '{print $2'} | sed -e s/\"//g`

# TLSv1と証明書チェックをスキップするためのオプション
cmd_options='--tlsv1.0 --insecure'

# セッションIDの取得
session_id=`curl -v $cmd_options $url \
 -d method=authenticate \
 -d username=admin \
 -d password=a10 | \
 sed -n -e 's/.*<session_id>\(.*\)<\/session_id>.*/\1/p'`
a
# ロードバランサに登録されているIPアドレス取得
ip=`curl -v -X GET $cmd_options $url \
    -d session_id=$session_id \
    -d method=slb.server.search \
    -d name=$instance_name | \
    sed -n -e 's/.*<host>\(.*\)<\/host>.*/\1/p'`

# サーバ削除
curl -v -X POST $cmd_options $url \
    -d session_id=$session_id \
    -d method=slb.server.delete \
    -d name=$instanceid

# インスタンス終了をAuto Scalingへ通知
aws autoscaling complete-lifecycle-action --lifecycle-name $lifecycle_name \
    --auto-scaling-group-name $ag_name \
    --life-cycle-action-token $token \
    --life-cycle-action-result CONTINUE
