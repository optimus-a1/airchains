
#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 提示用户输入节点名称，并将输入存储在变量 id 中
read -p "输入你的节点名称: " id
export id

# 更新系统并安装必要的依赖
apt update && apt install build-essential git make jq curl clang pkg-config libssl-dev -y

# 安装web3
pip3 install web3

# 安装Go
wget -c https://golang.org/dl/go1.22.3.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile && source /etc/profile

# 检查Go版本
go version


#安装检错重启脚本
# 定义要创建的脚本的名称
script_name="check.sh"

# 定义要写入的脚本内容
script_content='#!/bin/bash

# 定义服务名称
service_name="tracksd"

# 重启并启用服务的函数
restart_and_enable_service() {
    echo "发现错误。正在启用并重启 $service_name..."
    systemctl enable $service_name
    systemctl restart $service_name
    if [ $? -eq 0 ]; then
        echo "$service_name 已成功重启。"
    else
        echo "重启 $service_name 失败。请检查服务状态。"
    fi
}

# 停止服务并执行回滚的函数
stop_and_rollback_service() {
    echo "发现 invalid request 错误。正在停止 $service_name 并执行回滚..."
    systemctl stop $service_name
    /data/airchains/tracks/build/tracks rollback
    /data/airchains/tracks/build/tracks rollback
    /data/airchains/tracks/build/tracks rollback
    systemctl restart $service_name
    if [ $? -eq 0 ]; then
        echo "$service_name 已成功重启。"
    else
        echo "重启 $service_name 失败。请检查服务状态。"
    fi
}

# 检查最近的日志条目是否包含指定的错误
error_found=$(journalctl -u $service_name -n 50 | grep -E "incorrect pod number|rpc error|Failed to get transaction by hash: not found")
invalid_request_found=$(journalctl -u $service_name -n 50 | grep -E "invalid request \[cosmos/cosmos-sdk@v0.50.3/baseapp/baseapp.go:991\] with gas used")

if [ -n "$invalid_request_found" ]; then
    stop_and_rollback_service
elif [ -n "$error_found" ]; then
    restart_and_enable_service
else
    echo "没有检测到错误。"
fi

echo "程序执行完毕，即将退出。"
exit 0
'

# 创建脚本文件并写入内容
echo "$script_content" > $script_name

# 赋予执行权限
chmod +x $script_name

echo "脚本 $script_name 创建并赋予执行权限成功。"


# 提示按任意键继续
read -n 1 -s -r -p "按任意键继续..."



# 克隆必要的仓库
mkdir -p /data/airchains/ && cd /data/airchains/
git clone https://github.com/airchains-network/evm-station.git
git clone https://github.com/airchains-network/tracks.git

# 设置并运行 Evm-Station
cd /data/airchains/evm-station && go mod tidy
/bin/bash ./scripts/local-setup.sh

# 提示按任意键继续
read -n 1 -s -r -p "保存助记词按任意键继续..."

# 使用 sed 命令来替换 ./scripts/local-setup.sh 文件中的 MONIKER 值
sed -i "s/MONIKER=\"localtestnet\"/MONIKER=\"$id\"/" ./scripts/local-setup.sh


# 获取钱包私钥
key=$(/bin/bash ./scripts/local-keys.sh)
export key
echo "$key"
read -n 1 -s -r -p "保存私匙后按任意键继续..."

# 获取钱包地址
address=$(python3 -c "import os; from web3 import Web3; w3 = Web3(); private_key = os.getenv('key'); account = w3.eth.account.from_key(private_key); print('Address:', account.address)" | cut -d ' ' -f 2)
export address

# 获取本机IP
ip=$(curl -s4 ifconfig.me/ip)
export ip

ip=$(curl -s4 ifconfig.me/ip)
export ip

content=$(cat <<EOF
from web3 import Web3

# 自定义配置
rpc_url = "http://${ip}:8545"  # 自定义的 RPC URL
chain_id = 1234  # 自定义的链 ID

# 钱包地址和私钥
sender_address = "${address}"  # 发送者钱包地址
sender_private_key = "${key}"  # 发送者钱包的私钥

# 接收者钱包地址和转账金额（以最小单位表示）
receiver_address = "${address}"  # 接收者钱包地址
amount = 1000000000000000000  # 转账金额（示例为 1个币）

# 创建 Web3 实例
web3 = Web3(Web3.HTTPProvider(rpc_url))

# 构建交易对象
transaction = {
    "to": receiver_address,
    "value": amount,
    "gas": 60000,  # 设置默认的 gas 数量
    "gasPrice": web3.to_wei(50, "gwei"),  # 设置默认的 gas 价格
    "nonce": web3.eth.get_transaction_count(sender_address),
    "chainId": chain_id,
}

# 签名交易
signed_txn = web3.eth.account.sign_transaction(transaction, sender_private_key)

# 发送交易
tx_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)

# 等待交易确认
tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)

# 输出交易结果
print("Transaction Hash:", tx_receipt.transactionHash.hex())
print("Gas Used:", tx_receipt.gasUsed)
print("Status:", tx_receipt.status)
EOF
)

echo "$content" > /root/send.py



# 把json-rpc监听地址改为0.0.0.0，后面小狐狸钱包添加自定义RPC需要使用这个端口
sed -i.bak 's@address = "127.0.0.1:8545"@address = "0.0.0.0:8545"@' ~/.evmosd/config/app.toml

# 创建systemd守护程序
cat > /etc/systemd/system/evmosd.service << EOF
[Unit]
Description=evmosd node
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/.evmosd
ExecStart=/data/airchains/evm-station/build/station-evm start --metrics "" --log_level "info" --json-rpc.api eth,txpool,personal,net,debug,web3 --chain-id "testname_1234-1"
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# 加载配置文件并加入开机自启
systemctl daemon-reload && systemctl enable evmosd

systemctl restart evmosd


# 使用eigenlayer作为DA
wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
chmod +x eigenlayer && mv eigenlayer /usr/local/bin/eigenlayer

# 会生成私钥和公钥，注意保存输出的信息！！！ 后面要用到
eigenlayer operator keys create  -i=true --key-type ecdsa  $id

# 提示备份私钥和公钥
read -n 1 -s -r -p "备份输出的私匙和公匙按任意键继续..."

# 提示输入刚才Public Key hex并存储到变量 pkey 中
read -p "输入你的公钥 (Public Key hex): " pkey
export pkey

# 提示按任意键继续
read -n 1 -s -r -p "按任意键继续..."

cd /data/airchains/tracks/ && make build

# 使用eigenlayer作da的初始化命令
/data/airchains/tracks/build/tracks init --daRpc "disperser-holesky.eigenda.xyz" --daKey "$pkey" --daType "eigen" --moniker "$id" --stationRpc "http://127.0.0.1:8545" --stationAPI "http://127.0.0.1:8545" --stationType "evm"

/data/airchains/tracks/build/tracks keys junction --accountName $id --accountPath $HOME/.tracks/junction-accounts/keys

# 提示按任意键继续
read -n 1 -s -r -p "把助记词和内容保存和对air地址进行领水操作后按任意键继续..."

read -p "输入你刚才备份的air地址: " add
export add


# 运行Prover组件
/data/airchains/tracks/build/tracks prover v1EVM



# 获取bootstrapNode值
nodeid=$(grep "node_id" ~/.tracks/config/sequencer.toml | awk -F '"' '{print $2}')
ip=$(curl -s4 ifconfig.me/ip)
bootstrapNode="/ip4/$ip/tcp/2300/p2p/$nodeid"
export bootstrapNode



/data/airchains/tracks/build/tracks create-station --accountName $id --accountPath $HOME/.tracks/junction-accounts/keys --jsonRPC "https://airchains-rpc.sbgid.com/" --info "EVM Track" --tracks "$add" --bootstrapNode "$bootstrapNode"

# 创建systemd守护程序
cat > /etc/systemd/system/tracksd.service << EOF
[Unit]
Description=tracksd
After=network-online.target

[Service]
User=root
WorkingDirectory=/root/.tracks
ExecStart=/data/airchains/tracks/build/tracks start

Restart=always
RestartSec=10
LimitNOFILE=65535
SuccessExitStatus=0 1
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tracksd
systemctl restart tracksd

journalctl -u tracksd -f
