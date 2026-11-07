
FROM ghcr.io/engigu/baihu:latest

ENV REMOTE_FOLDER="huggingface:baihu"

RUN apt-get update && apt-get install -y \
    jq \
    xvfb \
    curl \
    unzip \
    sshpass \
    openssh-client \
    && curl -fsSL https://rclone.org/install.sh | bash \
    && rclone version \
    && ssh -V \
    && sshpass -V \
    && rm -rf /var/lib/apt/lists/*

RUN rclone config -h

COPY ./restore.sh /

# 替换新版 Baihu 启动函数
RUN sed -i 's/^start_baihu_server "\$@"$/sh \/restore.sh/' /app/docker-entrypoint.sh \
    && echo "========== 修改后的 ENTRYPOINT ==========" \
    && tail -n 15 /app/docker-entrypoint.sh \
    && grep -q '^sh /restore.sh$' /app/docker-entrypoint.sh

RUN mise exec python@3.13.12 -- pip install requests
RUN mise use -g python@3.13.12
RUN mise use -g node@23.11.1
