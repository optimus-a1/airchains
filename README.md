脚本参考了@TestnetCn大佬，其教程链接https://medium.com/@TestnetCn/airchains-rollapp%E9%83%A8%E7%BD%B2-3842a6cba873

wget -O airchains.sh https://raw.githubusercontent.com/optimus-a1/airchains/main/airchains.sh && chmod +x airchains.sh && ./airchains.sh


cd


screen -S send


while true; do python3 send.py; sleep 1; done



执行后按Ctrl+A+D退出


设定定时出错检查并进行重启和回滚

#添加定时
crontab -e

#设定每十分钟检查一次
*/10 * * * * /root/check.sh" | crontab -

#查看定时任务清单
crontab -l
