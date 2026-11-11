
#!/bin/sh

# 获取 Baihu 实际监听端口
BAIHU_PORT="${BH_SERVER_PORT:-${PORT:-8052}}"
BAIHU_URL="http://127.0.0.1:${BAIHU_PORT}"

# 获取登录 Cookie
USERNAME="admin"

echo "开始登录 Baihu，端口：${BAIHU_PORT}......"

BHToken=$(
    curl -c cookies.txt -s -D - -o /dev/null \
    "${BAIHU_URL}/api/v1/auth/login" \
    -H 'content-type: application/json' \
    --data-raw "{\"username\":\"$USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" \
    | awk -F'[=;]' '/Set-Cookie: BHToken=/{print $2}'
)

if [ -z "$BHToken" ]; then
    echo "登录失败，请检查密码和 Baihu 服务状态"
    exit 1
fi

echo "登录成功，开始请求备份"

# 请求生成备份
BACKUP_RESPON=$(
    curl -b cookies.txt -s -X POST \
    "${BAIHU_URL}/api/v1/settings/backup" \
    -H 'content-type: application/json'
)

echo "备份请求完成，等待10秒"

sleep 10

# 获取备份目录下的最新文件
latest_file=$(ls -t /app/data/backups 2>/dev/null | head -n 1)

if [ -z "$latest_file" ]; then
    echo "错误：没有找到备份文件"
    rm -f cookies.txt
    exit 1
fi

echo "最新备份：$latest_file"

# 删除云端旧备份
rclone delete "$REMOTE_FOLDER"

# 上传新备份
rclone copy "/app/data/backups/$latest_file" "$REMOTE_FOLDER"

# 删除本地临时备份
rm -f "/app/data/backups/$latest_file"

rm -f cookies.txt

echo "备份完成"
