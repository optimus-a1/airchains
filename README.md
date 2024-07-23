脚本参考了@TestnetCn大佬，其教程链接https://medium.com/@TestnetCn/airchains-rollapp%E9%83%A8%E7%BD%B2-3842a6cba873

wget -O airchains.sh https://raw.githubusercontent.com/optimus-a1/airchains/main/airchains.sh && chmod +x airchains.sh && ./airchains.sh


cd


screen -S send


while true; do python3 send.py; sleep 1; done



执行后按Ctrl+A+D退出


202407023升级最新版本(在7月23日前安装的可升级，7月23日后安装的不用升级，观察分数正常增长，也可以不升级）

git clone https://github.com/airchains-network/tracks.git 


cd tracks/ &&  make build 


systemctl stop tracksd


cp ./build/tracks /data/airchains/tracks/build/tracks


systemctl restart tracksd



20240710更新钉钉每天早上6点和下午报到，没有报告的请人工进行检查是否停止工作


20240709更新日志监控脚本，可以发送信息到钉钉,脚本修改WeiLao大哥的脚本，WeiLao大哥教程连接https://medium.com/@weilao0113/%E5%AE%9A%E6%97%B6%E7%9B%91%E6%8E%A7airchains-station-%E6%8C%82%E4%BA%86%E6%97%B6%E5%8F%91%E9%80%81%E9%92%89%E9%92%89%E6%8E%A8%E9%80%81-bcff4bffab26









手动更换rpc


#把其中的JunctionRPC:"改为rpc网址"改为下面导入小青蛙钱包测试通过的rpc网址


vim ~/.tracks/config/sequencer.toml

#用指令更改rpc

#备份配置文件


cp ~/.tracks/config/sequencer.toml ~/.tracks/config/sequencer.toml.bak


#更改配置文件

sed -i 's|JunctionRPC = "https://airchains-rpc.kubenode.xyz/"|JunctionRPC = "https://airchains-rpc.sbgid.com/"|' ~/.tracks/config/sequencer.toml

#重新启动tracksd


systemctl enable tracksd


systemctl restart tracksd



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






#老版本安装钉钉日志


#册除老的日志监控脚本


rm -r check.sh

#下载钉钉监控日志

wget -O dindin.sh https://raw.githubusercontent.com/optimus-a1/airchains/main/dindin.sh && chmod +x dingding.sh


#修改脚本的中你钉钉的内空和你服务器名称


vim dindin.sh


#在后台运行钉钉监控脚本


nohup /root/dindin.sh &



#查看脚本运行日志，退出按ctrl+c



tail -f /root/monitor.log




