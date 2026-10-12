FROM docker:dind

# 安装 openssh（含 sshd 与 ssh-keygen）
RUN apk add --no-cache openssh \
    && ssh-keygen -A \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# 注入 Jenkins 部署公钥（私钥在 Jenkins 凭据 server-deploy-key 中）
RUN mkdir -p /root/.ssh \
    && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILncwCVvYEhq0jGwrIk6MwDAs0qKVObVF4F7sVZwZavW jenkins-deploy" > /root/.ssh/authorized_keys \
    && chmod 700 /root/.ssh \
    && chmod 600 /root/.ssh/authorized_keys

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
