#!/bin/bash

# 确保脚本以 root 用户身份运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 用户运行此脚本。"
    exit 1
fi

# 读取用户输入的公钥
read -p "请输入 root 用户的公钥内容: " ssh_key

# 备份当前的 sshd_config 文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 修改 sshd_config 文件
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*$/PermitRootLogin without-password/' /etc/ssh/sshd_config

# 确保 root 用户的 .ssh 目录和 authorized_keys 文件存在
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 将用户的公钥添加到 authorized_keys 文件中
echo "$ssh_key" >> /root/.ssh/authorized_keys

# 函数：检查并重启 SSH 服务
restart_ssh_service() {
    if command -v systemctl >/dev/null 2>&1; then
        # 使用 systemctl 重启 SSH 服务
        echo "使用 systemctl 重启 SSH 服务..."
        systemctl restart sshd
        return 0
    elif command -v service >/dev/null 2>&1; then
        # 使用 service 重启 SSH 服务
        echo "使用 service 重启 SSH 服务..."
        service ssh restart
        return 0
    elif [ -x /etc/init.d/ssh ]; then
        # 使用 /etc/init.d/ 脚本重启 SSH 服务
        echo "使用 /etc/init.d/ssh 重启 SSH 服务..."
        /etc/init.d/ssh restart
        return 0
    elif command -v initctl >/dev/null 2>&1; then
        # 使用 initctl 重启 SSH 服务（适用于 Upstart）
        echo "使用 initctl 重启 SSH 服务..."
        initctl restart ssh
        return 0
    else
        # 无法识别的服务管理工具
        echo "无法识别的服务管理工具。请手动重启 SSH 服务。"
        return 1
    fi
}

# 尝试重启 SSH 服务
if restart_ssh_service; then
    echo "SSH 服务已成功重启。"
else
    echo "重启 SSH 服务失败。"
    exit 1
fi

echo "root 用户的 SSH 登录方式已成功更改为密钥登录。"
