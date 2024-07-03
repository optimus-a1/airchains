脚本参考了@TestnetCn大佬，其教程链接https://medium.com/@TestnetCn/airchains-rollapp%E9%83%A8%E7%BD%B2-3842a6cba873

wget -O airchains.sh https://raw.githubusercontent.com/optimus-a1/airchains/main/airchains.sh && chmod +x airchains.sh && ./airchains.sh


cd


screen -S send


while true; do python3 send.py; sleep 1; done



执行后按Ctrl+A+A退出
