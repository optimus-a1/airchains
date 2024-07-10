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


#安装日志检查监控脚本

# 提示用户选择功能
echo "请选择要安装的监控脚本："
echo "1. 安装发送信息到钉钉的监控脚本"
echo "2. 安装不发送信息到钉钉的监控脚本"
read choice

case $choice in
  1)
    # 安装发送信息到钉钉的监控脚本
    echo "正在安装发送信息到钉钉的监控脚本..."

    # 提示用户输入webhook，并将输入存储在变量 webhook 中
    read -p "输入你的钉钉机器人的webhook: " webhook

    # 提示用户输入钉钉加签秘钥，并将输入存储在变量 mkey 中
    read -p "输入你的钉钉机器人的加签秘钥: " mkey

    # 写入脚本的内容
    content=$(cat <<EOF
#!/bin/bash

# 钉钉机器人 WebHook URL 和密钥
WEBHOOK_URL="$webhook"
SECRET="$mkey"

# 定义检查关键词
KEYWORDS=("Success")
# 定义检查时间段（秒）每次执行时查询60秒内的日志有没有出现过关键词
CHECK_INTERVAL=60
# 定义脚本运行间隔时间（秒），脚本每60秒执行一次
SCRIPT_INTERVAL=60
# 定义180秒检查时间段（秒）180秒内没日志就重启
EXTENDED_CHECK_INTERVAL=180

LOG_FILE="/root/monitor.log"

# 计算签名
calculate_signature() {
    local timestamp=$(date "+%s%3N")
    local secret="$SECRET"
    local string_to_sign="${timestamp}\n${secret}"
    local sign=$(echo -ne "${string_to_sign}" | openssl dgst -sha256 -hmac "${secret}" -binary | base64)
    echo "${timestamp}&${sign}"
}

# 发送钉钉消息
send_dingtalk_message() {
    local message=$1
    local sign=$(calculate_signature)
    local url="${WEBHOOK_URL}&timestamp=$(echo ${sign} | cut -d'&' -f1)&sign=$(echo ${sign} | cut -d'&' -f2)"

    # 添加当前时间到消息内容中
    local current_time=$(TZ="Asia/Shanghai" date "+%Y-%m-%d %H:%M:%S")
    local message_with_time="${current_time} - $id - ${message}"

    echo "发送钉钉消息: ${message_with_time}" >> "$LOG_FILE"

    curl -s -X POST "${url}" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"${message_with_time}\"}}"
}

# 每天固定时间报告
daily_report() {
    local current_hour=$(date "+%H")
    local current_minute=$(date "+%M")

    if [[ "$current_hour" == "06" || "$current_hour" == "18" ]] && [[ "$current_minute" == "00" ]]; then
        send_dingtalk_message "向你报告"
    fi
}

LAST_EXTENDED_CHECK=$(date +%s)
RESTART_COUNT=0

while true; do
    echo "开始查询" >> "$LOG_FILE"
    current_time=$(TZ="Asia/Shanghai" date "+%Y-%m-%d %H:%M:%S")
    echo "$current_time - 开始查询" >> "$LOG_FILE"

    # 检查日志内容
    MATCH_FOUND=0
    LOGS=$(journalctl -u tracksd -o cat --since "${CHECK_INTERVAL} seconds ago" --until "now")

    if [ -z "$LOGS" ]; then
        # 如果没有任何日志输出，则直接发送消息
        MESSAGE="No log entries found in the last check interval"
        echo "$current_time - $MESSAGE" >> "$LOG_FILE"
        send_dingtalk_message "$MESSAGE"
    else
        echo "$current_time - 检查到的日志:" >> "$LOG_FILE"
        echo "$LOGS" >> "$LOG_FILE"
        while IFS= read -r line; do
            MESSAGE="$line"
            for keyword in "${KEYWORDS[@]}"; do
                if echo "$MESSAGE" | grep -q "$keyword"; then
                    MATCH_FOUND=1
                    echo "$current_time - 找到匹配的关键词: $keyword" >> "$LOG_FILE"
                    LAST_EXTENDED_CHECK=$(date +%s) # 更新上次找到关键词的时间
                    RESTART_COUNT=0 # 重置重启计数器
                    break 2
                fi
            done
        done <<< "$LOGS"

        # 如果未找到匹配的日志行，则发送钉钉消息
        if [ $MATCH_FOUND -eq 0 ]; then
            MESSAGE="No 'Successfully' or 'Success' found in the last check interval"
            echo "$current_time - $MESSAGE" >> "$LOG_FILE"
            send_dingtalk_message "$MESSAGE"
        fi
    fi

    # 检查是否超过180秒没有找到关键词
    current_timestamp=$(date +%s)
    time_diff=$((current_timestamp - LAST_EXTENDED_CHECK))
    if [ $time_diff -ge $EXTENDED_CHECK_INTERVAL ]; then
        echo "$current_time - 超过180秒没有找到关键词，执行重启命令" >> "$LOG_FILE"
        
        # 增加重启计数器
        RESTART_COUNT=$((RESTART_COUNT + 1))
        
        if [ $RESTART_COUNT -lt 3 ]; then
            systemctl restart tracksd
            send_dingtalk_message "超过180秒没有找到关键词，执行重启命令 (第${RESTART_COUNT}次)"
        else
            # 连续三次重启后执行特定操作
            sudo systemctl stop tracksd
           
            /data/airchains/tracks/build/tracks rollback
            /data/airchains/tracks/build/tracks rollback
            /data/airchains/tracks/build/tracks rollback
            systemctl restart tracksd
            send_dingtalk_message "连续三次重启后执行特定操作"
            RESTART_COUNT=0 # 重置重启计数器
        fi
        
        LAST_EXTENDED_CHECK=$(date +%s) # 重置检查时间
    fi

    daily_report  # 调用每日报告函数

    # 等待一段时间后再次检查
    sleep $SCRIPT_INTERVAL
done
EOF
)

    # 创建脚本文件并写入内容
    echo "$content" > /root/dindin.sh

    # 赋予执行权限
    chmod +x /root/dindin.sh

    echo "脚本 dindin.sh 创建并赋予执行权限成功。"

    nohup /root/dindin.sh &

    echo "脚本dindin.sh 在后台执行成功，查看运行日志执行  tail -f /root/monitor.log指令。"

    echo "发送信息到钉钉的监控脚本安装完成。"
    ;;
  2)
    # 安装不发送信息到钉钉的监控脚本
    echo "正在安装不发送信息到钉钉的监控脚本..."
    # 这里插入安装不发送信息到钉钉的监控脚本的命令

    # 写入要创建的脚本内容
    content=$(cat <<'EOF'
#!/bin/bash

# 定义检查关键词
KEYWORDS=("Success")
# 定义检查时间段（秒）每次执行时查询60秒内的日志有没有出现过关键词
CHECK_INTERVAL=60
# 定义脚本运行间隔时间（秒），脚本每60秒执行一次
SCRIPT_INTERVAL=60
# 定义180秒检查时间段（秒）180秒内没日志就重启
EXTENDED_CHECK_INTERVAL=180

LOG_FILE="/root/monitor.log"

# 初始化上次检查时间 简单理解就是上次出现success的时间（脚本执行时查到有日志的时间，和当前时间比较超过EXTENDED_CHECK_INTERVAL就重启）
LAST_EXTENDED_CHECK=$(date +%s)
# 重启标识把，查到有succes就重置，重启就会+1 直到重启三次就执行回滚
RESTART_COUNT=0

while true; do
    echo "开始查询" >> "$LOG_FILE"
    current_time=$(TZ="Asia/Shanghai" date "+%Y-%m-%d %H:%M:%S")
    echo "$current_time - 开始查询" >> "$LOG_FILE"

    # 检查日志内容
    MATCH_FOUND=0
    LOGS=$(journalctl -u tracksd -o cat --since "${CHECK_INTERVAL} seconds ago" --until "now")

    if [ -z "$LOGS" ]; then
        # 如果没有任何日志输出，则直接记录消息
        MESSAGE="No log entries found in the last check interval"
        echo "$current_time - $MESSAGE" >> "$LOG_FILE"
    else
        echo "$current_time - 检查到的日志:" >> "$LOG_FILE"
        echo "$LOGS" >> "$LOG_FILE"
        while IFS= read -r line; do
            MESSAGE="$line"
            for keyword in "${KEYWORDS[@]}"; do
                if echo "$MESSAGE" | grep -q "$keyword"; then
                    MATCH_FOUND=1
                    echo "$current_time - 找到匹配的关键词: $keyword" >> "$LOG_FILE"
                    LAST_EXTENDED_CHECK=$(date +%s) # 更新上次找到关键词的时间
                    RESTART_COUNT=0 # 重置重启计数器
                    break 2
                fi
            done
        done <<< "$LOGS"

        # 如果未找到匹配的日志行，则记录消息
        if [ $MATCH_FOUND -eq 0 ]; then
            MESSAGE="No 'Successfully' or 'Success' found in the last check interval"
            echo "$current_time - $MESSAGE" >> "$LOG_FILE"
        fi
    fi

    # 检查是否超过180秒没有找到关键词
    current_timestamp=$(date +%s)
    time_diff=$((current_timestamp - LAST_EXTENDED_CHECK))
    if [ $time_diff -ge $EXTENDED_CHECK_INTERVAL ]; then
        echo "$current_time - 超过180秒没有找到关键词，执行重启命令" >> "$LOG_FILE"
        
        # 增加重启计数器
        RESTART_COUNT=$((RESTART_COUNT + 1))
        
        if [ $RESTART_COUNT -lt 3 ]; then
            systemctl restart tracksd
            echo "$current_time - 超过180秒没有找到关键词，执行重启命令 (第${RESTART_COUNT}次)" >> "$LOG_FILE"
        else
            # 连续三次重启后执行特定操作
            sudo systemctl stop tracksd
           
            /data/airchains/tracks/build/tracks rollback
            /data/airchains/tracks/build/tracks rollback
            /data/airchains/tracks/build/tracks rollback
            systemctl restart tracksd
            echo "$current_time - 连续三次重启后执行特定操作" >> "$LOG_FILE"
            RESTART_COUNT=0 # 重置重启计数器
        endif
        
        LAST_EXTENDED_CHECK=$(date +%s) # 重置检查时间
    fi

    # 等待一段时间后再次检查
    sleep $SCRIPT_INTERVAL
done
EOF
)

    # 创建脚本文件并写入内容
    echo "$content" > /root/check.sh

    # 赋予执行权限
    chmod +x /root/check.sh

    echo "脚本check.sh创建并赋予执行权限成功。"

    nohup /root/check.sh &

    echo "脚本check.sh在后台执行成功，查看运行日志执行 tail -f /root/monitor.log 指令。"

    echo "不发送信息到钉钉的监控脚本安装完成。"
    ;;
  *)
    echo "无效选项。请重新运行脚本并选择1或2。"
    ;;
esac


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




# 提示用户选择功能
echo "请选择功能："
echo "1. 创建新的钱包"
echo "2. 导入助记词"
read choice

case $choice in
  1)
    # 创建钱包，生成私钥和公钥
    echo "正在创建钱包..."
    /data/airchains/tracks/build/tracks keys junction --accountName $id --accountPath $HOME/.tracks/junction-accounts/keys
    echo "钱包创建完成，把助记词和输出的内容保存。"
    ;;
  2)
    # 导入助记词
    echo "请输入您的助记词："
    read mnemonic
    echo "正在导入助记词..."
    go run cmd/main.go keys import --accountName $id --accountPath $HOME/.tracks/junction-accounts/keys --mnemonic "$mnemonic"
    echo "助记词已成功导入。"
    ;;
  *)
    echo "无效选项。请重新运行脚本并选择1或2。"
    ;;
esac


# 提示按任意键继续
read -n 1 -s -r -p "把air地址进行领水操作后按任意键继续..."

read -p "输入您的air地址: " add
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
