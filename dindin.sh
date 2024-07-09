#!/bin/bash

# 钉钉机器人 WebHook URL 和密钥
WEBHOOK_URL="替换为你的WEBHOOK"
SECRET="替换为你的秘钥"

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

    # 等待一段时间后再次检查
    sleep $SCRIPT_INTERVAL
done
