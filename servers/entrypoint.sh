#!/bin/sh
# 配置国内镜像加速器（Docker Hub 在你这网络不通，走 DaoCloud 镜像源）
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://docker.m.daocloud.io"]
}
EOF

# 后台启动 dockerd（Docker-in-Docker），让本容器具备 build/run 能力
dockerd-entrypoint.sh > /var/log/dockerd.log 2>&1 &

# 等待 docker 就绪
for i in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
done

# 前台运行 sshd，供 Jenkins 通过 SSH 推送文件并执行命令
exec /usr/sbin/sshd -D
