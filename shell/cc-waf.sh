#!/bin/bash
#该脚本可以根据web日志的访问量，自动拉黑IP（加入计划任务，结合计划任务在固定时间段内执行，并根据该时间段内产生的日志进行分析）

#首先把日志保存到根目录一份，计算日志有多少行
line1=`wc -l /access_log|awk '{print$1}'`
cp /var/log/httpd/access_log /

#计算现有的日志有多少行
line2=`wc -l /var/log/httpd/access_log |awk '{print$1}'`

#根据上一次备份的日志和现在拥有的行数差值，作为单位时间内分析日志访问量
tail -n $((line2-line1)) /var/log/httpd/access_log|awk '{print$1}'|sort -n|uniq -c|sort >/tmp/1.txt

cat /tmp/1.txt|while read line
do 
echo $line >/line
num=`awk '{print$1}' /line`

#设定阀值num，单位时间内操作这个访问量的ip会被自动拉黑
if (($num>12))
then
    ip=`awk '{print$2}' /line`
    firewall-cmd --add-rich-rule="rule family=ipv4 source address='${ip}' port port=80 protocol=tcp reject" --permanent
    firewall-cmd --reload

fi
done