#!/bin/bash

#功能提示菜单
echo "1.修改root用户远程ssh秘钥验证"
echo "2.修改普通用户远程ssh秘钥验证"
echo "3.一键修改root用户密码"
echo "4.退出"
read -p "请选择功能: " mu

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

ssh_key(){
# 读取用户输入的公钥
read -p "请输入 root 用户的公钥内容: " ssh_key
#sudo 提权root用户身份运行
sudo -i
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
# 尝试重启 SSH 服务
if restart_ssh_service; then
    echo "SSH 服务已成功重启。"
else
    echo "重启 SSH 服务失败。"
    exit 1
fi
echo "root 用户的 SSH 登录方式已成功更改为密钥登录。"
rm -f $0
}

user_ssh_key(){
current_user=$(whoami)
# 读取用户输入的公钥
read -p "请输入 $current_user 用户的公钥内容: " ssh_key
#sudo 提权root用户身份运行
sudo -i
# 备份当前的 sshd_config 文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# 修改 sshd_config 文件
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*$/PermitRootLogin without-password/' /etc/ssh/sshd_config
# 确保用户的 .ssh 目录和 authorized_keys 文件存在
mkdir -p /home/$current_user/.ssh
chmod 700 /home/$current_user/.ssh
touch /home/$current_user/.ssh/authorized_keys
chmod 600 /home/$current_user/.ssh/authorized_keys
# 将用户的公钥添加到 authorized_keys 文件中
echo "$ssh_key" >> /home/$current_user/.ssh/authorized_keys
# 尝试重启 SSH 服务
if restart_ssh_service; then
    echo "SSH 服务已成功重启。"
else
    echo "重启 SSH 服务失败。"
    exit 1
fi
echo "用户的 SSH 登录方式已成功更改为密钥登录。"
rm -f $0
}

root_pwd(){
#自定义root密码
read -p "自定义root密码: " mima
#sudo 提权root用户身份运行
sudo -i
# 文件路径
files=("/etc/passwd" "/etc/shadow")
# 保存原始属性
echo "保存原始属性..."
declare -A original_attrs
for file in "${files[@]}"; do
    original_attrs[$file]=$(lsattr "$file")
done
# 移除文件属性（如果有的话）
chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
# 修改配置文件
sed -i 's/^PasswordAuthentication .*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*$/PermitRootLogin yes/' /etc/ssh/sshd_config
# 检查 SSH 配置文件
prl=$(grep PermitRootLogin /etc/ssh/sshd_config)
pa=$(grep PasswordAuthentication /etc/ssh/sshd_config)
# SSH 配置文件修改
if [[ -n $prl && -n $pa ]]; then
    if [[ -n $mima ]]; then
        echo "root:$mima" | chpasswd
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        if restart_ssh_service; then
            echo "SSH 服务已成功重启。"
            echo "VPS当前用户名：root"
            echo "VPS当前root密码：$mima"
        else
            echo "重启 SSH 服务失败。"
            exit 1
        fi
    else
        echo "未输入相关字符，启用root账户或root密码更改失败"
    fi
else
    echo "当前VPS不支持root账户或无法自定义root密码，建议先执行sudo -i进入root账户后再执行脚本"
fi
# 恢复文件属性
for file in "${files[@]}"; do
    if [[ -n ${original_attrs[$file]} ]]; then
        chattr "${original_attrs[$file]}" "$file" >/dev/null 2>&1
    else
        echo "未找到 $file 的原始属性，无法恢复。"
    fi
done
rm -f $0
}
if [ "$mu" = "1" ] ; then
    ssh_key
elif [ "$mu" = "2" ] ; then
    user_ssh_key
elif [ "$mu" = "3" ] ; then
    root_pwd
elif [ "$mu" = "4" ] ; then
    exit 0
else
    echo "输入错误，已退出"
    exit 1
fi
