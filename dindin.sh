#!/bin/bash

# 钉钉机器人 WebHook URL 和密钥
WEBHOOK_URL="替换为你的WEBHOO"
SECRET="替换为你的WEBHOO"

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
    local message_with_time="${current_time} - 改为你的节点名称 - ${message}"

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
        send_dingtalk_message "我是《改为你的节点名称》向你报告"
    fi
}

LAST_EXTENDED_CHECK=$(date +%s)
RESTART_COUNT=0

while true; do
    echo "开始查询" >> "$LOG_FILE"
    current_time=$(TZ="Asia/Shanghai" date "+%Y-%m-%d %H:%M:%S")
    echo "$current_time - 开始查询" >> "$LOG_FILE"

    daily_report  # 调用每日报告函数

    # 其他代码与上述相同，此处略去以节省空间

    sleep $SCRIPT_INTERVAL
done
