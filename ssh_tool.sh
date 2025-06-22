#!/bin/bash

set -e
#功能提示菜单
echo "1.修改root用户远程ssh秘钥验证"
echo "2.修改普通用户远程ssh秘钥验证"
echo "3.一键修改root用户密码"
echo "4.一键修改ssh端口号"
echo "5.防火墙安装"
echo "6.防火墙端口设置"
echo "7.fail2ban，ssh登录防护"
echo "8.设置Swap大小"
echo "9.退出"
read -p "请选择功能: " mu


if [[ $EUID -ne 0 ]]; then
    su='sudo'
fi
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
if [[ $EUID -ne 0 ]]; then
    echo "请以 root 用户运行此脚本，或者先执行sudo -i进入root账户后再执行脚本"
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
$su sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
$su sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
$su sed -i 's/^PermitRootLogin .*$/PermitRootLogin without-password/' /etc/ssh/sshd_config
# 确保用户的 .ssh 目录和 authorized_keys 文件存在
$su mkdir -p /home/$current_user/.ssh
$su chmod 700 /home/$current_user/.ssh
$su touch /home/$current_user/.ssh/authorized_keys
$su chmod 600 /home/$current_user/.ssh/authorized_keys
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

ssh_port(){
#自定义修改端口号
read -p "自定义修改ssh端口号：" por
sudo sed -i "s/^#Port .*$/Port $por/" /etc/ssh/sshd_config
sudo sed -i "s/^Port .*$/Port $por/" /etc/ssh/sshd_config

# 重启 SSH 服务
sudo systemctl restart sshd
echo "SSH 端口已修改为 $por 并重新启动服务，请在防火墙开放端口号"
rm -f $0
}

fire_install(){
#防火墙安装
echo "1.UFW安装"
echo "2.firewalld安装"
read -p "Debian/Ubuntu 请选择 UFW 防火墙,RedHat/CentOS 请选择 Firewall 防火墙：" num1
read -p "放开ssh端口号：" shp8
read -p "是否需要放开1panel端口号[y/n]：" YN
if [ "$YN" = "y" ];then
    read -p "请输入1panel端口号：" shp1
fi
if [ "$num1" = "1" ];then
    $su apt update
    $su apt install ufw -y
    $su ufw allow $shp8/tcp
    if [ "$YN" = "y" ];then
        $su ufw allow $shp1/tcp
    fi
    firew=iptables-allports
    $su ufw enable
    echo "UFW安装完成，已开放端口号 $shp8;$shp1"
elif [ "$num1" = "2" ];then
    $su yum update
    $su yum install firewalld -y
    $su firewall-cmd --zone=public --add-port=$shp8/tcp --permanent
        if [ "$YN" = "y" ];then
        $su firewall-cmd --zone=public --add-port=$shp1/tcp --permanent
    fi
    $su systemctl start firewalld
    $su firewall-cmd --reload
    $su systemctl enable firewalld
    firew=firewallcmd-ipset
    echo "firewalld安装完成,已开放端口号 $shp8;$shp1"
fi
rm -f $0
}

#防火墙设置
fire_set(){
echo "1.端口开放"
echo "2.端口关闭"
read -p "请选择端口行为：" port2
#端口放开
fire_oport1(){
read -p "请输入开放端口号：" oport1
read -p "请输入开放协议[tcp/udp]：" xy
if command -v ufw >/dev/null 2>&1; then
    $su ufw allow $oport1/$xy
    $su ufw reload
    echo "已开放端口$oport1"
    $su ufw status numbered
elif command -v firewalld >/dev/null 2>&1; then
    $su firewall-cmd --zone=public --add-port=$oport1/$xy --permanent
    $su firewall-cmd --reload
    echo "已开放端口$oport1"
    $su firewall-cmd --list-ports
else
    echo "未安装UFW或者firewalld"
fi
}
#端口关闭
fire_close1(){
read -p "请输入关闭端口号：" close1
read -p "请输入对应协议[tcp/udp]：" xy
if command -v ufw >/dev/null 2>&1; then
    $su ufw status
    $su ufw delete allow "$close1/$xy"
    $su ufw reload
    echo "已关闭端口$close1"
    $su ufw status
elif command -v firewalld >/dev/null 2>&1; then
    $su firewall-cmd --list-ports
    $su firewall-cmd --permanent --remove-port="$close1/$xy"
    $su firewall-cmd --reload
    echo "已关闭端口$close1"
    $su firewall-cmd --list-ports
else
    echo "未安装UFW或者firewalld"
fi
}
if [ "$port2" = "1" ];then
    fire_oport1
elif [ "$port2" = "2" ];then
    fire_close1
fi
rm -f $0
}

F2b_install(){
#Fail2ban安装
read -p "ssh端口号：" fshp
read -p "IP封禁时间(单位s，-1为永久封禁)：" time1
echo "请选择封禁方式："
echo "1. iptables-allports"
echo "2. iptables-multiport"
echo "3. firewallcmd-ipset"
echo "4. ufw"

read -p "输入选择（1-4）：" manner1
# 设置默认封禁方式
manner=""
if [ "$manner1" = "1" ]; then
    manner="iptables-allports"
elif [ "$manner1" = "2" ]; then
    manner="iptables-multiport"
elif [ "$manner1" = "3" ]; then
    manner="firewallcmd-ipset"
elif [ "$manner1" = "4" ]; then
    manner="ufw"
else
    echo "无效输入，请选择 1、2、3 或 4。"
    exit 1
fi
echo "您选择的封禁方式是：$manner"

if command -v apt >/dev/null 2>&1; then
    $su apt update
    $su apt-get install fail2ban -y
    $su apt-get install rsyslog -y
else
    $su yum update
    $su yum install -y epel-release
    $su yum install -y fail2ban
fi
$su rm -rf /etc/fail2ban/jail.local
cat > /etc/fail2ban/jail.local << EOF
#DEFAULT-START
[DEFAULT]
bantime = 600
findtime = 300
maxretry = 5
banaction = $manner
action = %(action_mwl)s
#DEFAULT-END

[sshd]
ignoreip = 127.0.0.1/8
enabled = true
filter = sshd
port = $fshp 
maxretry = 5
findtime = 300
bantime = $time1
banaction = $manner
action = %(action_mwl)s
logpath = /var/log/auth.log
EOF
$su systemctl start fail2ban
$su systemctl enable fail2ban
echo "fail2ban已安装，修改配置文件在/etc/fail2ban/jail.local"
$su systemctl status fail2ban
rm -f $0
}

root_pwd(){
#自定义root密码
read -p "自定义root密码: " mima
# 文件路径
files=("/etc/passwd" "/etc/shadow")
# 保存原始属性
echo "保存原始属性..."
declare -A original_attrs
for file in "${files[@]}"; do
    original_attrs[$file]=$(lsattr "$file")
done
# 移除文件属性（如果有的话）
$su chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
$su chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
# 检查 SSH 配置文件
prl=$(grep PermitRootLogin /etc/ssh/sshd_config)
pa=$(grep PasswordAuthentication /etc/ssh/sshd_config)
# SSH 配置文件修改
if [[ -n $prl && -n $pa ]]; then
    if [[ -n $mima ]]; then
        echo "root:$mima" | chpasswd
        $su sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        $su sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
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

set_swap(){
# 默认SWAP大小，单位为GB
SWAP_SIZE_GB=2
SWAP_FILE="/swapfile"
SWAP_PRIORITY=0

# 检查是否有root权限
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本。"
  exit 1
fi

# 获取用户输入
read -p "请输入SWAP大小（单位GB，默认2）：" input_size
if [[ $input_size =~ ^[0-9]+$ ]]; then
  SWAP_SIZE_GB=$input_size
fi

read -p "请输入SWAP文件路径（默认/swapfile）：" input_file
if [[ -n $input_file ]]; then
  SWAP_FILE=$input_file
fi

read -p "请输入SWAP利用优先级（默认0）：" input_priority
if [[ $input_priority =~ ^[0-9]+$ ]]; then
  SWAP_PRIORITY=$input_priority
fi

read -p "是否设置SWAP开机自启动？(y/n，默认y)：" input_autostart
if [[ "$input_autostart" =~ ^[nN]$ ]]; then
  ENABLE_AUTOSTART=false
else
  ENABLE_AUTOSTART=true
fi

# 检查是否已有SWAP
if swapon --show | grep -q "$SWAP_FILE"; then
  echo "检测到SWAP文件 $SWAP_FILE，调整大小为 ${SWAP_SIZE_GB}GB..."
  swapoff $SWAP_FILE
  fallocate -l ${SWAP_SIZE_GB}G $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1G count=$SWAP_SIZE_GB
  chmod 600 $SWAP_FILE
  mkswap $SWAP_FILE
  swapon --priority $SWAP_PRIORITY $SWAP_FILE
  echo "SWAP文件大小已调整完成并重新启用。"
  if [ "$ENABLE_AUTOSTART" = true ]; then
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
      echo "$SWAP_FILE none swap sw,pri=$SWAP_PRIORITY 0 0" >> /etc/fstab
    fi
  fi
  exit 0
fi

# 创建SWAP文件
create_swapfile() {
  echo "创建${SWAP_SIZE_GB}GB的SWAP文件在${SWAP_FILE}..."
  fallocate -l ${SWAP_SIZE_GB}G $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1G count=$SWAP_SIZE_GB
  chmod 600 $SWAP_FILE
  mkswap $SWAP_FILE
  swapon --priority $SWAP_PRIORITY $SWAP_FILE
  if [ "$ENABLE_AUTOSTART" = true ]; then
    echo "$SWAP_FILE none swap sw,pri=$SWAP_PRIORITY 0 0" >> /etc/fstab
  fi
  echo "SWAP文件创建完成并已启用。"
}

# 创建SWAP分区（备用功能）
create_swap_partition() {
  echo "检测系统是否有未使用的分区..."
  AVAILABLE_PART=$(lsblk -npo NAME,TYPE,SIZE | grep -w "part" | awk '$3=="0B" {print $1}' | head -n 1)
  if [ -z "$AVAILABLE_PART" ]; then
    echo "未找到未使用的分区，改用SWAP文件。"
    create_swapfile
    return
  fi

  echo "找到未使用的分区：$AVAILABLE_PART"
  mkswap $AVAILABLE_PART
  swapon --priority $SWAP_PRIORITY $AVAILABLE_PART
  if [ "$ENABLE_AUTOSTART" = true ]; then
    echo "$AVAILABLE_PART none swap sw,pri=$SWAP_PRIORITY 0 0" >> /etc/fstab
  fi
  echo "SWAP分区设置完成并已启用。"
}

# 主逻辑
if free | awk '/^Swap:/ {exit !$2}'; then
  echo "系统已有SWAP，不需要新增。"
else
  if lsblk | grep -q swap; then
    echo "检测到SWAP分区，启用中..."
    swapon -a
  else
    create_swapfile
  fi
fi

# 检查设置是否正确
if [ "$ENABLE_AUTOSTART" = true ]; then
  echo "检查开机自启动设置..."
  if grep -q "$SWAP_FILE" /etc/fstab || grep -q "$AVAILABLE_PART" /etc/fstab; then
    echo "SWAP开机自启动已正确配置。"
  else
    echo "SWAP开机自启动配置失败，请检查/etc/fstab文件。"
  fi
fi

# 检查结果
echo "当前SWAP状态："
free -h
swapon --show
}

if [ "$mu" = "1" ] ; then
    ssh_key
elif [ "$mu" = "2" ] ; then
    user_ssh_key
elif [ "$mu" = "3" ] ; then
    root_pwd
elif [ "$mu" = "4" ] ; then
    ssh_port
elif [ "$mu" = "5" ] ; then
    fire_install
elif [ "$mu" = "6" ] ; then
    fire_set
elif [ "$mu" = "7" ] ; then
    F2b_install
elif [ "$mu" = "8" ] ; then
    set_swap
elif [ "$mu" = "9" ] ; then
    exit 0
else
    echo "输入错误，已退出"
    exit 1
fi
