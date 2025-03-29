#!/bin/bash

# 适用于：Oracle Cloud、CentOS、Ubuntu等Linux系统
# 作者：TSE+AI助手
# 版本：2025.1
# 定义颜色变量
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}请使用 sudo -i 切换至 root 用户后再次运行此脚本${NC}"
    exit 1
fi

# 函数：显示主菜单
show_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}               服务器配置管理工具               ${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}1. 设置主机名${NC}"
    echo -e "${YELLOW}2. 设置ROOT密码${NC}"
    echo -e "${YELLOW}3. 配置SSH端口${NC}"
    echo -e "${YELLOW}4. 配置PS1提示符${NC}"
    echo -e "${YELLOW}5. Oracle Cloud 系统服务管理${NC}"
    echo -e "${YELLOW}6. 一键配置所有选项${NC}"
    echo -e "${RED}0. 退出${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

# 函数：系统服务管理菜单
show_service_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}               Oracle Cloud 系统服务管理菜单               ${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}1. 停止并禁用 Oracle Cloud 相关服务${NC}"
    echo -e "${YELLOW}2. 停止并禁用 RPC 相关服务${NC}"
    echo -e "${YELLOW}3. 停止并禁用防火墙${NC}"
    echo -e "${YELLOW}4. 清除防火墙规则${NC}"
    echo -e "${YELLOW}5. 执行所有服务管理操作${NC}"
    echo -e "${RED}0. 返回主菜单${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

# 函数：获取用户输入
get_input() {
    local prompt=$1
    local var_name=$2
    local default=$3
    echo -e "${YELLOW}$prompt ${NC}${GREEN}[$default]${NC}: \c"
    read input
    if [ -z "$input" ]; then
        eval $var_name="$default"
    else
        eval $var_name="$input"
    fi
}

# 函数：设置主机名
set_hostname() {
    get_input "请输入新的主机名" "hostname" "server"
    echo -e "${BLUE}正在设置主机名...${NC}"
    sed -i "s/$(hostname)/$hostname/g" /etc/hosts
    echo "$hostname" > /etc/hostname
    hostnamectl set-hostname "$hostname"
    echo -e "${GREEN}主机名已设置为: $hostname${NC}"
}

# 函数：设置ROOT密码
set_root_password() {
    get_input "请输入新的ROOT密码" "root_password" "password123"
    echo -e "${BLUE}正在设置ROOT密码...${NC}"
    echo "root:$root_password" | chpasswd
    echo -e "${GREEN}ROOT密码设置完成${NC}"
}

# 函数：配置SSH
configure_ssh() {
    get_input "请输入新的SSH端口" "ssh_port" "22"

    # 端口检查：优先使用 netstat，如果没有则使用 ss
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":$ssh_port\b"; then
            echo -e "${RED}端口 $ssh_port 已被占用${NC}"
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":$ssh_port\b"; then
            echo -e "${RED}端口 $ssh_port 已被占用${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}警告: 未找到 netstat 或 ss 命令，跳过端口占用检查${NC}"
    fi

    echo -e "${BLUE}正在配置SSH...${NC}"
    sed -i -e "s/^#\?Port .*/Port $ssh_port/g" \
           -e 's/^#\?PermitRootLogin .*/PermitRootLogin yes/g' \
           -e 's/^#\?MaxSessions .*/MaxSessions 1/g' \
           -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/g' \
           -e 's/^#\?ClientAliveInterval .*/ClientAliveInterval 55/g' \
           /etc/ssh/sshd_config

    systemctl restart ssh
    echo -e "${GREEN}SSH配置完成，新端口: $ssh_port${NC}"
}

# 函数：配置PS1颜色
configure_ps1() {
    # 更全面的颜色支持检测
    HAS_COLOR=0
    # 方法1: 检查 TERM 变量
    if [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
        # 方法2: 检查是否支持 tput
        if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
            HAS_COLOR=1
        # 方法3: 直接测试颜色输出
        elif echo -e "\033[0;31m" 2>/dev/null; then
            HAS_COLOR=1
        fi
    fi

    echo -e "${BLUE}正在配置PS1提示符...${NC}"

    # root用户配置
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${GREEN}以ROOT用户身份配置所有用户的PS1...${NC}"

        # 遍历所有用户目录
        cat /etc/passwd | while IFS=: read -r username _ userid _ _ homedir _; do
            if [ "$userid" -ge 1000 ] || [ "$username" = "root" ]; then
                if [ -d "$homedir" ]; then
                    # 确定配置文件
                    if [ -f "$homedir/.bashrc" ]; then
                        CONFIG_FILE="$homedir/.bashrc"
                    else
                        # 如果用户没有.bashrc，使用全局配置
                        CONFIG_FILE="/etc/profile"
                    fi

                    # 检查是否已配置
                    if ! grep -q "# PS1_CONFIG_2025" "$CONFIG_FILE"; then
                        # 为root用户配置红色提示符，为普通用户配置蓝色提示符
                        if [ "$userid" -eq 0 ]; then
                            if [ "$HAS_COLOR" -eq 1 ]; then
                                echo 'PS1="◆\033[1;31m\u\033[0m@\h:\w# "                # PS1_CONFIG_2025' >> "$CONFIG_FILE"
                                echo 'echo -e "\033[41;37m当前是 $USER 用户...\033[0m"  # PS1_CONFIG_2025' >> "$CONFIG_FILE"
                            else
                                echo 'PS1="◆\u@\h:\w# "     # PS1_CONFIG_2025' >> "$CONFIG_FILE"
                                echo 'echo -e "\033[41;37m当前是 $USER 用户...\033[0m"      # PS1_CONFIG_2025' >> "$CONFIG_FILE"
                            fi
                            echo -e "已为 ${RED}root${NC} 配置PS1到 $CONFIG_FILE"
                        else
                            if [ "$HAS_COLOR" -eq 1 ]; then
                                echo 'PS1="\033[1;34m\u\033[0m@\h:\w$ "    # PS1_CONFIG_2025' >> "$CONFIG_FILE"
                            else
                                echo 'PS1="\u@\h:\w$ "    # PS1_CONFIG_2025' >> "$CONFIG_FILE"
                            fi
                            echo -e "已为用户 ${BLUE}$username${NC} 配置PS1到 $CONFIG_FILE"
                        fi
                    else
                        echo -e "${YELLOW}用户 $username 的PS1已配置在 $CONFIG_FILE${NC}"
                    fi
                fi
            fi
        done
    else
        # 普通用户配置
        echo -e "${YELLOW}以普通用户身份仅配置当前用户的PS1...${NC}"

        # 确定配置文件
        if [ -f ~/.bashrc ]; then
            CONFIG_FILE=~/.bashrc
        else
            CONFIG_FILE=/etc/profile
        fi

        # 检查是否已配置
        if ! grep -q "# PS1_CONFIG_2025" "$CONFIG_FILE"; then
            if [ "$HAS_COLOR" -eq 1 ]; then
                echo 'PS1="\033[1;34m\u\033[0m@\h:\w$ "    # PS1_CONFIG_2025' >> "$CONFIG_FILE"
            else
                echo 'PS1="\u@\h:\w$ "    # PS1_CONFIG_2025' >> "$CONFIG_FILE"
            fi
            echo -e "${GREEN}已配置当前用户的PS1到 $CONFIG_FILE${NC}"
        else
            echo -e "${YELLOW}当前用户的PS1已配置在 $CONFIG_FILE${NC}"
        fi
    fi

    echo -e "${GREEN}PS1配置完成，重新登录后生效${NC}"
}

# 函数：管理Oracle Cloud服务
manage_oracle_services() {
    echo -e "${BLUE}正在处理Oracle Cloud服务...${NC}"
    systemctl stop oracle-cloud-agent
    systemctl disable oracle-cloud-agent
    systemctl stop oracle-cloud-agent-updater
    systemctl disable oracle-cloud-agent-updater
    echo -e "${GREEN}Oracle Cloud服务已停止并禁用${NC}"
}

# 函数：管理RPC服务
manage_rpc_services() {
    echo -e "${BLUE}正在处理RPC服务...${NC}"
    systemctl stop rpcbind
    systemctl stop rpcbind.socket
    systemctl disable rpcbind
    systemctl disable rpcbind.socket
    echo -e "${GREEN}RPC服务已停止并禁用${NC}"
}

# 函数：管理防火墙
manage_firewall() {
    echo -e "${BLUE}正在处理防火墙...${NC}"
    systemctl stop firewalld
    systemctl disable firewalld
    echo -e "${GREEN}防火墙已停止并禁用${NC}"
}

# 函数：清除防火墙规则
clear_firewall_rules() {
    echo -e "${BLUE}正在清除防火墙规则...${NC}"
    rm -f /etc/iptables/rules.v4
    rm -f /etc/iptables/rules.v6
    echo -e "${GREEN}防火墙规则已清除${NC}"
}

# 服务管理主函数
handle_services() {
    while true; do
        show_service_menu
        echo -e "${YELLOW}请选择操作 [0-5]:${NC} \c"
        read service_choice
        case $service_choice in
            1) manage_oracle_services ;;
            2) manage_rpc_services ;;
            3) manage_firewall ;;
            4) clear_firewall_rules ;;
            5)
                manage_oracle_services
                manage_rpc_services
                manage_firewall
                clear_firewall_rules
                ;;
            0) return ;;
            *) echo -e "${RED}无效的选项${NC}" ;;
        esac
        [ "$service_choice" != "0" ] && read -p "按回车继续..."
    done
}

# 主程序循环
while true; do
    show_menu
    echo -e "${YELLOW}请选择操作 [0-6]:${NC} \c"
    read choice

    case $choice in
        1) set_hostname ;;
        2) set_root_password ;;
        3) configure_ssh ;;
        4) configure_ps1 ;;
        44)
            # 隐藏功能：清除所有PS1配置
            echo -e "${YELLOW}正在清除PS1配置...${NC}"

            # 清除root用户和所有普通用户的PS1配置
            cat /etc/passwd | while IFS=: read -r username _ userid _ _ homedir _; do
                if [ "$userid" -ge 1000 ] || [ "$username" = "root" ]; then
                    if [ -d "$homedir" ]; then
                        if [ -f "$homedir/.bashrc" ]; then
                            sed -i '/# PS1_CONFIG_2025/d' "$homedir/.bashrc"
                            echo -e "已清除 ${BLUE}$username${NC} 的PS1配置 (bashrc)"
                        fi
                    fi
                fi
            done

            # 清除全局配置
            if [ -f "/etc/profile" ]; then
                sed -i '/# PS1_CONFIG_2025/d' "/etc/profile"
                echo -e "已清除全局PS1配置 (profile)"
            fi

            echo -e "${GREEN}PS1配置清除完成，重新登录后生效${NC}"
            ;;
        5) handle_services ;;
        6)
            set_hostname
            set_root_password
            configure_ssh
            configure_ps1
            handle_services
            echo -e "${GREEN}所有配置已完成！${NC}"
            read -p "是否需要重启系统? (y/N): " restart
            if [[ $restart =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}系统将在3秒后重启...${NC}"
                sleep 3
                reboot
            fi
            ;;
        0)
            echo -e "${GREEN}感谢使用！再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选项，请重试${NC}"
            sleep 2
            ;;
    esac

    [ "$choice" != "6" ] && [ "$choice" != "0" ] && read -p "按回车继续..."
done
