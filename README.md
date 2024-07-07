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

*/10 * * * * /root/check.sh

#查看定时任务清单

crontab -l









更换rpc

vim ~/.tracks/config/sequencer.toml




https://airchains-rpc-testnet.zulnaaa.com/


https://t-airchains.rpc.utsa.tech/



https://airchains.rpc.t.stavr.tech/


https://airchains-rpc.chainad.org/


https://junction-rpc.kzvn.xyz/


https://airchains-rpc.elessarnodes.xyz/


https://airchains-testnet-rpc.apollo-sync.com/


https://rpc-airchain.danggia.xyz/


https://airchains-rpc.stakeme.pro/


https://airchains-testnet-rpc.crouton.digital/ 


https://airchains-testnet-rpc.itrocket.net/


https://rpc1.airchains.t.cosmostaking.com/


https://rpc.airchain.yx.lu/


https://airchains-testnet-rpc.staketab.org/


https://junction-rpc.owlstake.com/


https://rpctt-airchain.sebatian.org/


https://rpc.airchains.aknodes.net/


https://airchains-rpc-testnet.zulnaaa.com/


https://rpc-testnet-airchains.nodeist.net/


https://airchains-testnet.rpc.stakevillage.net/


https://airchains-rpc.sbgid.com/


https://airchains-test.rpc.moonbridge.team/


https://rpc-airchains-t.sychonix.com/


https://airchains-rpc.anonid.top/


https://rpc.airchains.stakeup.tech/


https://junction-testnet-rpc.nodesync.top/


https://rpc-airchain.vnbnode.com/


https://airchain-t-rpc.syanodes.my.id


https://airchains-test-rpc.nodesteam.tech/



https://junction-rpc.validatorvn.com/




#手动回滚


systemctl stop tracksd


/data/airchains/tracks/build/tracks rollback


/data/airchains/tracks/build/tracks rollback


/data/airchains/tracks/build/tracks rollback


systemctl restart tracksd











