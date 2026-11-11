
#!/bin/sh

# 获取 Baihu 实际监听端口
BAIHU_PORT="${BH_SERVER_PORT:-${PORT:-8052}}"
BAIHU_URL="http://127.0.0.1:${BAIHU_PORT}"

echo "======================================"
echo "Baihu 启动与恢复"
echo "监听端口：${BAIHU_PORT}"
echo "======================================"

npm install pm2 -g

# 开启白虎服务
pm2 start "./baihu server" --name baihu

echo "10秒后开始恢复任务..."
sleep 10

# 从日志中获取默认密码
echo "======================从日志中获取密码========================"

DEFAULT_PASSWORD=$(tail -n 100 ~/.pm2/logs/baihu-out.log \
    | grep -oP '密\s*码:\s*\K[^,[:space:]]+' \
    | tail -n 1)

echo "默认用户名: admin"

if [ -z "$DEFAULT_PASSWORD" ]; then
    echo "警告：没有获取到默认密码，请检查 Baihu 启动日志"
else
    echo "============重置密码==============="

    # 获取登录 Cookie
    BHToken=$(
        curl -c cookies.txt -s -D - -o /dev/null \
        "${BAIHU_URL}/api/v1/auth/login" \
        -H 'content-type: application/json' \
        --data-raw "{\"username\":\"admin\",\"password\":\"$DEFAULT_PASSWORD\"}" \
        | awk -F'[=;]' '/Set-Cookie: BHToken=/{print $2}'
    )

    sleep 1

    # 重置密码
    RESET_RESPONSE=$(
        curl -b cookies.txt -s \
        "${BAIHU_URL}/api/v1/settings/password" \
        -H 'content-type: application/json' \
        --data-raw "{\"old_password\":\"$DEFAULT_PASSWORD\",\"new_password\":\"$ADMIN_PASSWORD\"}"
    )

    echo "密码重置请求完成"
    echo "$RESET_RESPONSE"
fi

echo "======================写入rclone配置========================"

mkdir -p ~/.config/rclone
echo "$RCLONE_CONF" > ~/.config/rclone/rclone.conf

if [ -n "$RCLONE_CONF" ]; then
    echo "##########同步备份############"

    OUTPUT=$(rclone ls "$REMOTE_FOLDER" 2>&1)
    EXIT_CODE=$?

    if [ "$EXIT_CODE" -eq 0 ]; then

        if [ -z "$OUTPUT" ]; then
            echo "初次安装"
        else
            mkdir -p /app/backup_tmp

            # 找最新的备份文件
            latest_file=$(rclone lsjson "$REMOTE_FOLDER" \
                | jq -r 'sort_by(.ModTime) | last | .Path')

            if [ -n "$latest_file" ] && [ "$latest_file" != "null" ]; then

                # 下载最新备份
                rclone copy "$REMOTE_FOLDER/$latest_file" /app/backup_tmp

                # 恢复 Baihu 数据
                if [ -f "/app/backup_tmp/$latest_file" ]; then
                    ./baihu restore "/app/backup_tmp/$latest_file"
                    pm2 restart baihu
                fi
            fi

            rm -rf /app/backup_tmp
        fi

    else
        case "$OUTPUT" in
            *"directory not found"*)
                echo "错误：文件夹不存在"
                ;;
            *)
                echo "错误：$OUTPUT"
                ;;
        esac
    fi
else
    echo "没有检测到Rclone配置信息"
fi

echo "Baihu 初始化流程完成"

tail -f /dev/null
