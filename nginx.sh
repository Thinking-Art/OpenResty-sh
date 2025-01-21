#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 系统检测
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ]; then
            echo -e "${RED}此脚本仅支持Ubuntu系统${NC}"
            exit 1
        fi
        echo -e "${GREEN}系统检测: Ubuntu ${VERSION_ID}${NC}"
    else
        echo -e "${RED}无法确定系统类型${NC}"
        exit 1
    fi
}

# 检查OpenResty是否已安装
check_openresty() {
    echo -e "\n${GREEN}=== 检查OpenResty安装状态 ===${NC}"
    
    # 检查二进制文件
    if ! command -v openresty &> /dev/null; then
        echo -e "${YELLOW}OpenResty未安装${NC}"
        echo -e "请选择操作："
        echo "1. 安装OpenResty"
        echo "2. 返回主菜单"
        echo "3. 退出脚本"
        read -p "请输入选项 [1-3]: " install_choice
        case $install_choice in
            1)
                install_openresty
                ;;
            2)
                return
                ;;
            3)
                echo -e "${RED}已取消安装，退出脚本${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，退出脚本${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${GREEN}检测到OpenResty已安装${NC}"
        openresty_version=$(openresty -v 2>&1 | awk -F/ '{print $2}')
        echo -e "当前版本: ${GREEN}${openresty_version}${NC}"
        
        # 检查服务状态
        if systemctl is-active openresty >/dev/null 2>&1; then
            echo -e "服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "服务状态: ${RED}未运行${NC}"
            echo -e "请选择操作："
            echo "1. 启动OpenResty"
            echo "2. 继续使用"
            echo "3. 返回主菜单"
            read -p "请输入选项 [1-3]: " service_choice
            case $service_choice in
                1)
                    if systemctl start openresty; then
                        echo -e "${GREEN}OpenResty 已启动${NC}"
                    else
                        echo -e "${RED}启动失败，请检查错误日志${NC}"
                        echo -e "错误日志位置: ${BLUE}/usr/local/openresty/nginx/logs/error.log${NC}"
                    fi
                    ;;
                2)
                    echo -e "${YELLOW}继续使用...${NC}"
                    ;;
                3)
                    return
                    ;;
                *)
                    echo -e "${RED}无效的选择${NC}"
                    ;;
            esac
        fi
        
        # 检查配置文件
        if [ ! -f "/usr/local/openresty/nginx/conf/nginx.conf" ]; then
            echo -e "${RED}警告：配置文件丢失${NC}"
            echo -e "建议使用'恢复默认配置'功能修复"
        fi
    fi
}

# 简化的OpenResty安装函数
install_openresty() {
    echo -e "\n${GREEN}=== 开始安装OpenResty ===${NC}"
    echo "请选择安装选项："
    echo "1. 快速安装（仅基本组件）"
    echo "2. 完整安装（包含所有组件）"
    echo "3. 返回上级菜单"
    read -p "请输入选项 [1-3]: " install_type
    
    case $install_type in
        1|2)
            # 检查是否有其他包管理器进程
            while pgrep -x apt >/dev/null || pgrep -x dpkg >/dev/null; do
                echo -e "${YELLOW}等待其他包管理器进程完成...${NC}"
                sleep 5
            done
            
            # 修复可能的依赖问题
            echo -e "${GREEN}修复可能的依赖问题...${NC}"
            dpkg --configure -a
            apt-get install -f -y
            
            # 清理APT缓存
            echo -e "${GREEN}清理APT缓存...${NC}"
            apt-get clean
            apt-get autoclean
            
            # 更新系统并安装基础依赖
            echo -e "${GREEN}更新系统包列表...${NC}"
            if ! apt-get update; then
                echo -e "${RED}系统更新失败，请检查网络连接${NC}"
                return 1
            fi
            
            echo -e "${GREEN}安装基础依赖...${NC}"
            if ! apt-get install -y curl gnupg2 ca-certificates lsb-release debian-archive-keyring; then
                echo -e "${RED}安装基础依赖失败${NC}"
                return 1
            fi
            
            # 添加OpenResty仓库
            echo -e "${GREEN}添加OpenResty仓库...${NC}"
            if ! wget -qO - https://openresty.org/package/pubkey.gpg | apt-key add -; then
                echo -e "${RED}添加OpenResty密钥失败${NC}"
                return 1
            fi
            
            echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list
            
            # 再次更新包列表
            echo -e "${GREEN}更新包列表...${NC}"
            if ! apt-get update; then
                echo -e "${RED}更新包列表失败${NC}"
                return 1
            fi
            
            # 安装OpenResty
            echo -e "${GREEN}安装OpenResty...${NC}"
            if [ "$install_type" = "1" ]; then
                if ! apt-get install -y openresty; then
                    echo -e "${RED}安装OpenResty失败${NC}"
                    return 1
                fi
            else
                if ! apt-get install -y openresty openresty-opm openresty-restydoc; then
                    echo -e "${RED}安装OpenResty及其组件失败${NC}"
                    return 1
                fi
            fi
            
            # 创建必要目录
            echo -e "${GREEN}创建必要目录...${NC}"
            mkdir -p /usr/local/openresty/nginx/conf/sites-available
            mkdir -p /usr/local/openresty/nginx/conf/sites-enabled
            mkdir -p /usr/local/openresty/nginx/html
            
            # 设置权限
            echo -e "${GREEN}设置权限...${NC}"
            chown -R www-data:www-data /usr/local/openresty/nginx/html
            chmod -R 755 /usr/local/openresty/nginx/html
            
            # 创建默认页面
            echo -e "${GREEN}创建默认页面...${NC}"
            create_default_page
            
            # 添加自动热重载
            echo -e "${GREEN}设置自动热重载...${NC}"
            setup_auto_reload
            
            # 启动服务
            echo -e "${GREEN}启动OpenResty服务...${NC}"
            systemctl enable openresty
            if ! systemctl start openresty; then
                echo -e "${RED}启动OpenResty服务失败，请检查错误日志${NC}"
                echo -e "错误日志位置: ${BLUE}/usr/local/openresty/nginx/logs/error.log${NC}"
                return 1
            fi
            
            # 验证安装
            if systemctl is-active openresty >/dev/null 2>&1; then
                echo -e "${GREEN}OpenResty安装完成并成功启动！${NC}"
                echo -e "${GREEN}自动热重载服务已启用${NC}"
                show_openresty_info
            else
                echo -e "${RED}OpenResty安装完成但启动失败${NC}"
                echo -e "请检查错误日志: ${BLUE}/usr/local/openresty/nginx/logs/error.log${NC}"
                echo -e "您可以尝试手动启动: ${YELLOW}systemctl start openresty${NC}"
                return 1
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}无效的选择，返回上级菜单${NC}"
            return
                ;;
        esac
}

# 定义分隔线函数
print_separator() {
    local title="$1"
    local title_length=${#title}
    local separator=$(printf '%*s' "$title_length" | tr ' ' '=')
    
    echo -e "\n${GREEN}===${title}===${NC}"
}

# 显示OpenResty信息
show_openresty_info() {
    print_separator " OpenResty 信息 "
    if command -v openresty &> /dev/null; then
        version=$(openresty -v 2>&1 | awk -F/ '{print $2}')
        echo -e "版本: ${GREEN}${version}${NC}"
        echo -e "配置文件: ${BLUE}/usr/local/openresty/nginx/conf/nginx.conf${NC}"
        echo -e "网站目录: ${BLUE}/usr/local/openresty/nginx/html${NC}"
        
        if systemctl is-active openresty >/dev/null 2>&1; then
            echo -e "运行状态: ${GREEN}运行中${NC}"
            echo -e "内存占用: ${GREEN}$(ps aux | grep nginx | grep -v grep | awk '{sum+=$6} END {print sum/1024 "MB"}')"
            start_time=$(systemctl show openresty --property=ActiveEnterTimestamp | cut -d'=' -f2)
            current_time=$(date +%s)
            start_seconds=$(date -d "$start_time" +%s)
            uptime_seconds=$((current_time - start_seconds))
            
            days=$((uptime_seconds/86400))
            hours=$(((uptime_seconds%86400)/3600))
            minutes=$(((uptime_seconds%3600)/60))
            
            echo -e "已运行时间: ${GREEN}${days}天${hours}小时${minutes}分钟${NC}"
        else
            echo -e "运行状态: ${RED}未运行${NC}"
        fi
        echo -e "项目地址: ${BLUE}https://github.com/openresty/openresty${NC}"
    else
        echo -e "${RED}OpenResty未安装${NC}"
    fi
}

# 升级OpenResty
upgrade_openresty() {
    echo -e "\n${GREEN}=== 升级OpenResty ===${NC}"
    echo "1. 确认升级"
    echo "2. 返回上级菜单"
    read -p "请输入选项 [1-2]: " upgrade_choice
    case $upgrade_choice in
        1)
            echo -e "\n${GREEN}正在升级OpenResty...${NC}"
            apt update
            apt install --only-upgrade openresty -y
            systemctl restart openresty
            echo -e "${GREEN}升级完成！${NC}"
            show_openresty_info
            ;;
        2)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            return
            ;;
    esac
}

# 卸载OpenResty
uninstall_openresty() {
    echo -e "\n${RED}=== 卸载OpenResty ===${NC}"
    echo "1. 确认卸载"
    echo "2. 返回上级菜单"
    read -p "请输入选项 [1-2]: " uninstall_choice
    case $uninstall_choice in
        1)
            systemctl stop openresty
            apt remove --purge -y openresty
            rm -rf /usr/local/openresty
            rm -f /etc/apt/sources.list.d/openresty.list
            echo -e "${GREEN}OpenResty已完全卸载${NC}"
            exit 0
            ;;
        2)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            return
            ;;
    esac
}

# 输入验证函数
validate_input() {
    local input=$1
    local min=$2
    local max=$3
    local prompt=$4
    local result
    
    while true; do
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge "$min" ] && [ "$input" -le "$max" ]; then
            echo "$input"
    return 0
        fi
        read -p "${prompt} [${min}-${max}]: " result
        input=$result
    done
}

# 反向代理管理菜单
proxy_management_menu() {
    while true; do
        print_separator "反向代理管理"
        echo "1. 添加反向代理"
        echo "2. 删除反向代理"
        echo "3. 查看所有反向代理"
        echo "4. 返回主菜单"
        local menu_width=18  # 反向代理管理的长度加6
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        read -p "请输入选项 [1-4]: " choice
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        
        choice=$(validate_input "$choice" 1 4 "请输入正确的选项")
        
        case $choice in
            1)
                add_proxy
                ;;
            2)
                delete_proxy
                ;;
            3)
                list_proxies
                ;;
            4)
                return
            ;;
    esac
    done
}

# 添加反向代理
add_proxy() {
    read -p "请输入域名: " domain
    while [ -z "$domain" ]; do
        read -p "域名不能为空，请重新输入: " domain
    done
    
    read -p "请输入目标地址(例如: http://localhost:8080): " target
    while [ -z "$target" ]; do
        read -p "目标地址不能为空，请重新输入: " target
    done
    
    local conf_file="/usr/local/openresty/nginx/conf/sites-available/${domain}.conf"
    
    # 创建反向代理配置
    cat > "$conf_file" << EOF
# 反向代理配置：$domain -> $target
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    
    access_log /usr/local/openresty/nginx/logs/${domain}_access.log main;
    error_log /usr/local/openresty/nginx/logs/${domain}_error.log;
    
    # 禁用默认页面
    location = /nginx.html {
        return 404;
    }
    
    location / {
        proxy_pass $target;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 反向代理超时设置
        proxy_connect_timeout 60;
        proxy_send_timeout 60;
        proxy_read_timeout 60;
        
        # 反向代理缓冲设置
        proxy_buffer_size 4k;
        proxy_buffers 4 32k;
        proxy_busy_buffers_size 64k;
        
        # 错误处理
        proxy_intercept_errors on;
        error_page 502 503 504 = @proxy_error;
    }
    
    # 自定义错误页面
    location @proxy_error {
        internal;
        default_type text/html;
        return 502 '<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理服务器错误</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 650px;
            margin: 50px auto;
            padding: 0 20px;
            background: #f5f5f5;
        }
        .error-container {
            background: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #e53e3e; margin-top: 0; }
        .status { color: #718096; }
        .info { margin-top: 20px; padding-top: 20px; border-top: 1px solid #edf2f7; }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>代理服务器错误</h1>
        <p class="status">状态码: 502 Bad Gateway</p>
        <p>目标服务器暂时无法访问，请稍后重试。</p>
        <div class="info">
            <p>代理信息：</p>
            <ul>
                <li>域名：$domain</li>
                <li>目标地址：$target</li>
            </ul>
        </div>
    </div>
</body>
</html>';
    }
    
    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
    
    # 创建软链接
    ln -sf "$conf_file" "/usr/local/openresty/nginx/conf/sites-enabled/"
    
    # 测试并重载配置
    if openresty -t; then
        systemctl reload openresty
        echo -e "${GREEN}反向代理 $domain -> $target 创建成功！${NC}"
        echo -e "\n配置信息："
        echo -e "域名: ${GREEN}$domain${NC}"
        echo -e "目标地址: ${BLUE}$target${NC}"
        echo -e "配置文件: ${BLUE}$conf_file${NC}"
        echo -e "访问日志: ${BLUE}/usr/local/openresty/nginx/logs/${domain}_access.log${NC}"
        echo -e "错误日志: ${BLUE}/usr/local/openresty/nginx/logs/${domain}_error.log${NC}"
    else
        echo -e "${RED}配置测试失败${NC}"
        rm -f "$conf_file"
        rm -f "/usr/local/openresty/nginx/conf/sites-enabled/${domain}.conf"
    fi
}

# 删除反向代理
delete_proxy() {
    local sites_dir="/usr/local/openresty/nginx/conf/sites-available"
    local proxies=($(grep -l "proxy_pass" $sites_dir/*.conf 2>/dev/null | xargs -n1 basename 2>/dev/null))
    
    if [ ${#proxies[@]} -eq 0 ]; then
        echo -e "${RED}没有可用的反向代理${NC}"
        return
    fi
    
    echo "可用反向代理:"
    for i in "${!proxies[@]}"; do
        local domain=${proxies[$i]%.conf}
        local target=$(grep "proxy_pass" "$sites_dir/${proxies[$i]}" | awk '{print $2}' | tr -d ';')
        echo "$((i+1)). ${domain} -> ${target}"
    done
    
    read -p "选择要删除的反向代理编号: " choice
    choice=$(validate_input "$choice" 1 ${#proxies[@]} "请输入正确的编号")
    
    local proxy=${proxies[$((choice-1))]}
    local domain=${proxy%.conf}
    
    rm -f "$sites_dir/$proxy"
    rm -f "/usr/local/openresty/nginx/conf/sites-enabled/$proxy"
    
    if openresty -t; then
        systemctl reload openresty
        echo -e "${GREEN}反向代理已删除${NC}"
    else
        echo -e "${RED}配置测试失败${NC}"
    fi
}

# 列出所有反向代理
list_proxies() {
    echo -e "\n${GREEN}=== 反向代理列表 ===${NC}"
    local sites_dir="/usr/local/openresty/nginx/conf/sites-available"
    local count=0
    
    for conf in "$sites_dir"/*.conf; do
        if [ -f "$conf" ] && grep -q "proxy_pass" "$conf"; then
            local domain=$(basename "$conf" .conf)
            local target=$(grep "proxy_pass" "$conf" | awk '{print $2}' | tr -d ';')
            echo -e "\n域名: ${GREEN}$domain${NC}"
            echo -e "目标地址: ${BLUE}$target${NC}"
            echo -e "配置文件: ${BLUE}$conf${NC}"
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}暂无反向代理配置${NC}"
    fi
}

# 添加备份还原函数
backup_openresty() {
    local backup_dir="/usr/local/openresty/backup"
    local date_str=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/openresty_backup_$date_str.tar.gz"
    
    echo -e "\n${GREEN}=== 开始备份 OpenResty ===${NC}"
    
    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    # 复制配置文件和网站文件
    cp -r /usr/local/openresty/nginx/conf "$temp_dir/"
    cp -r /usr/local/openresty/nginx/html "$temp_dir/"
    
    # 创建备份信息文件
    cat > "$temp_dir/backup_info.txt" << EOF
备份时间: $(date "+%Y-%m-%d %H:%M:%S")
OpenResty版本: $(openresty -v 2>&1 | awk -F/ '{print $2}')
系统信息: $(lsb_release -ds)
EOF
    
    # 创建压缩文件
    tar -czf "$backup_file" -C "$temp_dir" .
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    if [ -f "$backup_file" ]; then
        echo -e "${GREEN}备份成功！${NC}"
        echo -e "备份文件: ${BLUE}$backup_file${NC}"
        echo -e "备份大小: ${GREEN}$(du -h "$backup_file" | cut -f1)${NC}"
    else
        echo -e "${RED}备份失败${NC}"
    fi
}

# 还原OpenResty
restore_openresty() {
    local backup_dir="/usr/local/openresty/backup"
    
    echo -e "\n${GREEN}=== 还原 OpenResty ===${NC}"
    
    # 检查备份目录是否存在
    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}未找到备份目录${NC}"
        echo "1. 返回上级菜单"
        read -p "请按1返回: " choice
        return
    fi
    
    # 获取备份文件列表
    local backups=($(ls $backup_dir/openresty_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}未找到备份文件${NC}"
        echo "1. 返回上级菜单"
        read -p "请按1返回: " choice
        return
    fi
    
    echo "可用备份:"
    for i in "${!backups[@]}"; do
        local file=${backups[$i]}
        local date_str=$(echo "$file" | grep -o "[0-9]\{8\}_[0-9]\{6\}")
        local size=$(du -h "$file" | cut -f1)
        echo "$((i+1)). $(date -d "${date_str:0:8} ${date_str:9:2}:${date_str:11:2}:${date_str:13:2}" "+%Y-%m-%d %H:%M:%S") (${size})"
    done
    echo "$((${#backups[@]}+1)). 返回上级菜单"
    
    read -p "选择要还原的备份编号: " choice
    if [ "$choice" = "$((${#backups[@]}+1))" ]; then
        return
    fi
    
    choice=$(validate_input "$choice" 1 ${#backups[@]} "请输入正确的编号")
    
    local selected_backup=${backups[$((choice-1))]}
    
    echo -e "${YELLOW}警告：还原将覆盖当前配置，建议先创建新的备份${NC}"
    echo "1. 继续还原"
    echo "2. 返回上级菜单"
    read -p "请输入选项 [1-2]: " confirm
    case $confirm in
        1)
            # 创建临时目录
            local temp_dir=$(mktemp -d)
            
            # 解压备份文件
            tar -xzf "$selected_backup" -C "$temp_dir"
            
            # 显示备份信息
            if [ -f "$temp_dir/backup_info.txt" ]; then
                echo -e "\n${GREEN}备份信息:${NC}"
                cat "$temp_dir/backup_info.txt"
            fi
            
            # 停止服务
            systemctl stop openresty
            
            # 备份当前配置
            mv /usr/local/openresty/nginx/conf /usr/local/openresty/nginx/conf.old
            mv /usr/local/openresty/nginx/html /usr/local/openresty/nginx/html.old
            
            # 还原文件
            cp -r "$temp_dir/conf" /usr/local/openresty/nginx/
            cp -r "$temp_dir/html" /usr/local/openresty/nginx/
            
            # 清理临时目录
            rm -rf "$temp_dir"
            
            # 设置权限
            chown -R www-data:www-data /usr/local/openresty/nginx/html
            chmod -R 755 /usr/local/openresty/nginx/html
            
            # 测试配置
            if openresty -t; then
                systemctl start openresty
                echo -e "${GREEN}还原成功！${NC}"
                rm -rf /usr/local/openresty/nginx/conf.old
                rm -rf /usr/local/openresty/nginx/html.old
            else
                echo -e "${RED}配置测试失败，正在回滚...${NC}"
                rm -rf /usr/local/openresty/nginx/conf
                rm -rf /usr/local/openresty/nginx/html
                mv /usr/local/openresty/nginx/conf.old /usr/local/openresty/nginx/conf
                mv /usr/local/openresty/nginx/html.old /usr/local/openresty/nginx/html
                systemctl start openresty
            fi
            ;;
        2)
            return
            ;;
        *)
            echo -e "${RED}无效的选择，返回上级菜单${NC}"
            return
            ;;
    esac
}

# 恢复默认配置
restore_default_config() {
    echo -e "\n${GREEN}=== 恢复默认配置 ===${NC}"
    echo -e "${RED}警告：此操作将清除所有OpenResty配置并恢复到全新安装状态！${NC}"
    echo "此操作将清除："
    echo "1. 所有站点配置"
    echo "2. 所有反向代理配置"
    echo "3. 所有SSL证书"
    echo "4. 所有日志文件"
    echo "5. 所有网站文件"
    echo -e "${RED}注意：此操作无法撤销，所有内容将被永久删除！${NC}"
    
    echo -e "\n请选择："
    echo "1. 确认恢复默认配置"
    echo "2. 返回上级菜单"
    read -p "请输入选项 [1-2]: " choice
    
    case $choice in
        1)
            echo -e "\n${YELLOW}最后确认：此操作将删除所有配置和文件！${NC}"
            read -p "请输入 'CONFIRM' 以继续: " confirm
            if [ "$confirm" != "CONFIRM" ]; then
                echo -e "${YELLOW}操作已取消${NC}"
                return
            fi
            
            echo -e "\n${GREEN}开始恢复默认配置...${NC}"
            
            # 停止服务
            systemctl stop openresty
            
            # 清理所有目录
            echo -e "${GREEN}1. 清理目录...${NC}"
            rm -rf /usr/local/openresty/nginx/conf/*
            rm -rf /usr/local/openresty/nginx/html/*
            rm -rf /usr/local/openresty/nginx/logs/*
            
            # 重建目录结构
            echo -e "${GREEN}2. 重建目录结构...${NC}"
            mkdir -p /usr/local/openresty/nginx/conf/sites-available
            mkdir -p /usr/local/openresty/nginx/conf/sites-enabled
            mkdir -p /usr/local/openresty/nginx/conf/ssl
            mkdir -p /usr/local/openresty/nginx/conf/conf.d
            mkdir -p /usr/local/openresty/nginx/html
            mkdir -p /usr/local/openresty/nginx/logs
            
            # 创建默认配置文件
            echo -e "${GREEN}3. 创建默认配置...${NC}"
            cat > "/usr/local/openresty/nginx/conf/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
error_log logs/error.log;
pid logs/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log logs/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;
    
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # SSL配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # 先加载站点配置
    include sites-enabled/*.conf;
    # 后加载默认配置
    include conf.d/*.conf;
}
EOF
            
            # 创建默认站点配置
            cat > "/usr/local/openresty/nginx/conf/conf.d/default.conf" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /usr/local/openresty/nginx/html;
    
    access_log /usr/local/openresty/nginx/logs/default_access.log main;
    error_log /usr/local/openresty/nginx/logs/default_error.log;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
    
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
            
            # 复制默认的mime.types文件
            cp /etc/nginx/mime.types /usr/local/openresty/nginx/conf/
            
            echo -e "${GREEN}4. 创建默认页面...${NC}"
            create_default_page
            
            echo -e "${GREEN}5. 设置权限...${NC}"
            chown -R www-data:www-data /usr/local/openresty/nginx/html
            chmod -R 755 /usr/local/openresty/nginx/html
            chmod 644 /usr/local/openresty/nginx/html/index.html
            
            echo -e "${GREEN}6. 测试配置...${NC}"
            if openresty -t; then
                systemctl restart openresty
                echo -e "\n${GREEN}恢复默认配置成功！${NC}"
                echo -e "OpenResty已恢复到全新安装状态"
                echo -e "您现在可以重新添加站点和配置"
            else
                echo -e "${RED}配置测试失败！${NC}"
                echo -e "请尝试重新安装OpenResty"
            fi
            ;;
        2)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            return
            ;;
    esac
}

# 修改系统维护菜单
system_maintenance_menu() {
    while true; do
        print_separator "升级/维护"
        echo "1. 启动服务"
        echo "2. 停止服务"
        echo "3. 重启服务"
        echo "4. 升级 OpenResty"
        echo "5. 卸载 OpenResty"
        echo "6. 备份配置"
        echo "7. 还原配置"
        echo "8. 恢复默认配置"
        echo "9. 返回主菜单"
        local menu_width=14  # 升级/维护的长度加6
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        read -p "请输入选项 [1-9]: " choice
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        
        choice=$(validate_input "$choice" 1 9 "请输入正确的选项")
        
        case $choice in
            1)
                systemctl start openresty
                echo -e "${GREEN}OpenResty 已启动${NC}"
                ;;
            2)
                systemctl stop openresty
                echo -e "${GREEN}OpenResty 已停止${NC}"
                ;;
            3)
                systemctl restart openresty
                echo -e "${GREEN}OpenResty 已重启${NC}"
                ;;
            4)
                echo -e "\n${GREEN}正在升级OpenResty...${NC}"
                apt update
                apt install --only-upgrade openresty -y
                systemctl restart openresty
                echo -e "${GREEN}升级完成！${NC}"
                show_openresty_info
                ;;
            5)
                echo -e "\n${RED}警告：此操作将完全删除OpenResty及其所有配置！${NC}"
                read -p "确认卸载？(y/n): " confirm
                if [[ $confirm == [Yy] ]]; then
                    systemctl stop openresty
                    apt remove --purge -y openresty
                    rm -rf /usr/local/openresty
                    rm -f /etc/apt/sources.list.d/openresty.list
                    echo -e "${GREEN}OpenResty已完全卸载${NC}"
                    exit 0
                fi
                ;;
            6)
                backup_openresty
                ;;
            7)
                restore_openresty
                ;;
            8)
                restore_default_config
                ;;
            9)
                return
                ;;
        esac
    done
}

# SSL证书管理菜单
ssl_management_menu() {
    while true; do
        print_separator "SSL证书管理"
        echo "1. 安装SSL证书"
        echo "2. 更新SSL证书"
        echo "3. 删除SSL证书"
        echo "4. 查看SSL证书"
        echo "5. 返回主菜单"
        local menu_width=17  # SSL证书管理的长度加6
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        read -p "请输入选项 [1-5]: " choice
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        
        choice=$(validate_input "$choice" 1 5 "请输入正确的选项")
        
        case $choice in
            1)
                install_ssl
                ;;
            2)
                update_ssl
                ;;
            3)
                delete_ssl
                ;;
            4)
                list_ssl
                ;;
            5)
                return
                ;;
        esac
    done
}

# 安装SSL证书
install_ssl() {
    read -p "请输入域名: " domain
    while [ -z "$domain" ]; do
        read -p "域名不能为空，请重新输入: " domain
    done
    
    # 检查域名配置是否存在
    local conf_file="/usr/local/openresty/nginx/conf/sites-available/${domain}.conf"
    if [ ! -f "$conf_file" ]; then
        echo -e "${RED}错误：域名 $domain 的配置文件不存在${NC}"
        echo "1. 返回上级菜单"
        read -p "请按1返回: " choice
        return
    fi
    
    # 创建SSL证书目录
    local ssl_dir="/usr/local/openresty/nginx/conf/ssl/${domain}"
    mkdir -p "$ssl_dir"
    
    echo -e "\n${GREEN}=== 证书安装向导 ===${NC}"
    echo "请选择证书输入方式："
    echo "1. 从文件读取"
    echo "2. 手动粘贴"
    echo "3. 返回上级菜单"
    read -p "请输入选项 [1-3]: " input_method
    
    case $input_method in
        1)
            echo -e "\n请输入证书文件路径："
            read -p "证书文件路径 (cert.pem): " cert_file
            read -p "私钥文件路径 (key.pem): " key_file
            
            if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
                echo -e "${RED}错误：证书文件不存在${NC}"
                return
            fi
            
            cp "$cert_file" "$ssl_dir/cert.pem"
            cp "$key_file" "$ssl_dir/key.pem"
            ;;
        2)
            echo -e "\n${YELLOW}请注意：${NC}"
            echo "1. 每个证书内容以 '-----BEGIN' 开头"
            echo "2. 每个证书内容以 '-----END' 结尾"
            echo "3. 完成输入后按 Ctrl+D 结束"
            
            echo -e "\n${GREEN}请粘贴证书内容：${NC}"
            cat > "$ssl_dir/cert.pem"
            
            if [ ! -s "$ssl_dir/cert.pem" ]; then
                echo -e "${RED}错误：未检测到证书内容${NC}"
                rm -f "$ssl_dir/cert.pem"
                return
            fi
            
            echo -e "\n${GREEN}请粘贴私钥内容：${NC}"
            cat > "$ssl_dir/key.pem"
            
            if [ ! -s "$ssl_dir/key.pem" ]; then
                echo -e "${RED}错误：未检测到私钥内容${NC}"
                rm -f "$ssl_dir/cert.pem" "$ssl_dir/key.pem"
                return
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            return
            ;;
    esac
    
    # 验证证书格式
    if ! openssl x509 -in "$ssl_dir/cert.pem" -noout 2>/dev/null; then
        echo -e "${RED}错误：无效的证书格式${NC}"
        rm -f "$ssl_dir/cert.pem" "$ssl_dir/key.pem"
        return
    fi
    
    if ! openssl rsa -in "$ssl_dir/key.pem" -check -noout 2>/dev/null; then
        echo -e "${RED}错误：无效的私钥格式${NC}"
        rm -f "$ssl_dir/cert.pem" "$ssl_dir/key.pem"
        return
    fi
    
    # 设置权限
    chmod 600 "$ssl_dir/key.pem"
    chmod 644 "$ssl_dir/cert.pem"
    
    # 备份原配置
    cp "$conf_file" "${conf_file}.bak"
    
    # 检查是否为反向代理配置
    local is_proxy=false
    local proxy_target=""
    if grep -q "proxy_pass" "$conf_file"; then
        is_proxy=true
        proxy_target=$(grep "proxy_pass" "$conf_file" | awk '{print $2}' | tr -d ';')
    fi
    
    # 读取原配置中的root和index指令
    local root_dir=$(grep -E "^\s*root\s+" "$conf_file" | awk '{print $2}' | tr -d ';')
    local index_line=$(grep -E "^\s*index\s+" "$conf_file" | head -n 1)
    
    if [ -z "$root_dir" ] && [ "$is_proxy" = false ]; then
        root_dir="/usr/local/openresty/nginx/html/${domain}"
    fi
    
    if [ -z "$index_line" ] && [ "$is_proxy" = false ]; then
        index_line="index index.html index.htm index.php;"
    fi
    
    # 修改Nginx配置
    cat > "$conf_file" << EOF
# 站点配置：$domain
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    
    # HTTP重定向HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;
    
EOF

    if [ "$is_proxy" = true ]; then
        # 添加反向代理配置
        cat >> "$conf_file" << EOF
    # 反向代理配置
    location / {
        proxy_pass $proxy_target;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60;
        proxy_send_timeout 60;
        proxy_read_timeout 60;
        proxy_buffer_size 4k;
        proxy_buffers 4 32k;
        proxy_busy_buffers_size 64k;
    }
EOF
    else
        # 添加普通站点配置
        cat >> "$conf_file" << EOF
    root $root_dir;
    $index_line
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
EOF
    fi

    # 添加SSL和其他通用配置
    cat >> "$conf_file" << EOF
    
    # SSL配置
    ssl_certificate /usr/local/openresty/nginx/conf/ssl/${domain}/cert.pem;
    ssl_certificate_key /usr/local/openresty/nginx/conf/ssl/${domain}/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # 日志配置
    access_log /usr/local/openresty/nginx/logs/${domain}_access.log;
    error_log /usr/local/openresty/nginx/logs/${domain}_error.log;
    
    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

    # 如果不是反向代理，确保网站目录存在
    if [ "$is_proxy" = false ]; then
        mkdir -p "$root_dir"
        chown -R www-data:www-data "$root_dir"
        chmod -R 755 "$root_dir"
    fi

    # 测试并重载配置
    if openresty -t; then
        systemctl reload openresty
        echo -e "${GREEN}SSL证书安装成功！${NC}"
        echo -e "已为 ${BLUE}$domain${NC} 启用HTTPS"
        
        # 显示证书信息
        echo -e "\n${GREEN}证书信息：${NC}"
        openssl x509 -in "$ssl_dir/cert.pem" -noout -dates -subject
        
        # 检查网站目录是否为空（仅对非反向代理）
        if [ "$is_proxy" = false ] && [ ! "$(ls -A $root_dir)" ]; then
            echo -e "\n${YELLOW}注意：网站目录为空，正在创建默认页面...${NC}"
            cp "/usr/local/openresty/nginx/html/index.html" "$root_dir/index.html"
            chown www-data:www-data "$root_dir/index.html"
            chmod 644 "$root_dir/index.html"
        fi
        
        echo -e "\n${GREEN}配置信息：${NC}"
        if [ "$is_proxy" = true ]; then
            echo -e "反向代理目标: ${BLUE}$proxy_target${NC}"
        else
            echo -e "网站目录: ${BLUE}$root_dir${NC}"
        fi
        echo -e "配置文件: ${BLUE}$conf_file${NC}"
        echo -e "证书文件: ${BLUE}$ssl_dir/cert.pem${NC}"
        echo -e "私钥文件: ${BLUE}$ssl_dir/key.pem${NC}"
    else
        echo -e "${RED}配置测试失败，正在还原配置...${NC}"
        mv "${conf_file}.bak" "$conf_file"
        rm -rf "$ssl_dir"
        systemctl reload openresty
    fi
}

# 更新SSL证书
update_ssl() {
    local ssl_dir="/usr/local/openresty/nginx/conf/ssl"
    local domains=($(ls $ssl_dir 2>/dev/null))
    
    if [ ${#domains[@]} -eq 0 ]; then
        echo -e "${RED}没有已安装的SSL证书${NC}"
        return
    fi
    
    echo "已安装SSL证书的域名:"
    for i in "${!domains[@]}"; do
        echo "$((i+1)). ${domains[$i]}"
    done
    
    read -p "选择要更新的域名编号: " choice
    choice=$(validate_input "$choice" 1 ${#domains[@]} "请输入正确的编号")
    
    local domain=${domains[$((choice-1))]}
    local cert_dir="$ssl_dir/$domain"
    
    # 备份原证书
    cp "$cert_dir/cert.pem" "$cert_dir/cert.pem.bak"
    cp "$cert_dir/key.pem" "$cert_dir/key.pem.bak"
    
    # 更新证书内容
    echo "请粘贴新的SSL证书内容 (以 END 结束):"
    cert_content=""
    while IFS= read -r line; do
        [ "$line" = "END" ] && break
        cert_content+="$line"$'\n'
    done
    echo "$cert_content" > "$cert_dir/cert.pem"
    
    echo "请粘贴新的私钥内容 (以 END 结束):"
    key_content=""
    while IFS= read -r line; do
        [ "$line" = "END" ] && break
        key_content+="$line"$'\n'
    done
    echo "$key_content" > "$cert_dir/key.pem"
    
    # 设置权限
    chmod 600 "$cert_dir/key.pem"
    chmod 644 "$cert_dir/cert.pem"
    
    # 测试并重载配置
    if openresty -t; then
        systemctl reload openresty
        echo -e "${GREEN}SSL证书更新成功！${NC}"
        rm -f "$cert_dir/cert.pem.bak" "$cert_dir/key.pem.bak"
    else
        echo -e "${RED}配置测试失败，正在还原原证书${NC}"
        mv "$cert_dir/cert.pem.bak" "$cert_dir/cert.pem"
        mv "$cert_dir/key.pem.bak" "$cert_dir/key.pem"
    fi
}

# 删除SSL证书
delete_ssl() {
    local ssl_dir="/usr/local/openresty/nginx/conf/ssl"
    local domains=($(ls $ssl_dir 2>/dev/null))
    
    if [ ${#domains[@]} -eq 0 ]; then
        echo -e "${RED}没有已安装的SSL证书${NC}"
        return
    fi
    
    echo "已安装SSL证书的域名:"
    for i in "${!domains[@]}"; do
        echo "$((i+1)). ${domains[$i]}"
    done
    
    read -p "选择要删除的域名编号: " choice
    choice=$(validate_input "$choice" 1 ${#domains[@]} "请输入正确的编号")
    
    local domain=${domains[$((choice-1))]}
    local conf_file="/usr/local/openresty/nginx/conf/sites-available/${domain}.conf"
    
    # 备份配置文件
    cp "$conf_file" "$conf_file.bak"
    
    # 修改Nginx配置，移除SSL相关配置
    sed -i '/ssl_/d' "$conf_file"
    sed -i 's/listen 443.*;//' "$conf_file"
    sed -i '/if ($scheme = http)/,+2d' "$conf_file"
    
    # 删除证书文件
    rm -rf "$ssl_dir/$domain"
    
    # 测试并重载配置
    if openresty -t; then
        systemctl reload openresty
        echo -e "${GREEN}SSL证书已删除${NC}"
        rm -f "$conf_file.bak"
    else
        echo -e "${RED}配置测试失败，正在还原配置${NC}"
        mv "$conf_file.bak" "$conf_file"
    fi
}

# 查看SSL证书
list_ssl() {
    echo -e "\n${GREEN}=== SSL证书列表 ===${NC}"
    local ssl_dir="/usr/local/openresty/nginx/conf/ssl"
    local count=0
    
    for domain in "$ssl_dir"/*; do
        if [ -d "$domain" ]; then
            local domain_name=$(basename "$domain")
            echo -e "\n域名: ${GREEN}$domain_name${NC}"
            echo -e "证书路径: ${BLUE}$domain/cert.pem${NC}"
            echo -e "私钥路径: ${BLUE}$domain/key.pem${NC}"
            
            # 显示证书信息
            if [ -f "$domain/cert.pem" ]; then
                echo -e "\n证书信息:"
                openssl x509 -in "$domain/cert.pem" -noout -dates -subject
            fi
            count=$((count + 1))
                fi
            done
            
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}暂无SSL证书${NC}"
    fi
}

# 修改主菜单
main_menu() {
    while true; do
        show_openresty_info
        print_separator "OpenResty 管理菜单"
        echo "1. 站点管理"
        echo "2. 反向代理管理"
        echo "3. SSL证书管理"
        echo "4. 升级/维护"
        echo "0. 退出"
        local menu_width=23  # OpenResty 管理菜单的长度加6（两边的===）
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        read -p "请输入选项 [0-4]: " choice
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        
        choice=$(validate_input "$choice" 0 4 "请输入正确的选项")
        
        case $choice in
            1)
                site_management_menu
                ;;
            2)
                proxy_management_menu
                ;;
            3)
                ssl_management_menu
                ;;
            4)
                system_maintenance_menu
                ;;
            0)
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
            ;;
    esac
    done
}

# 站点管理菜单
site_management_menu() {
    while true; do
        print_separator "站点管理"
        echo "1. 创建新站点"
        echo "2. 删除站点"
        echo "3. 查看所有站点"
        echo "4. 返回主菜单"
        local menu_width=14  # 站点管理的长度加6
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        read -p "请输入选项 [1-4]: " choice
        echo -e "${GREEN}$(printf '%*s' "$menu_width" | tr ' ' '=')${NC}"
        
        choice=$(validate_input "$choice" 1 4 "请输入正确的选项")
        
        case $choice in
            1)
                read -p "请输入域名: " domain
                while [ -z "$domain" ]; do
                    read -p "域名不能为空，请重新输入: " domain
                done
                create_site "$domain"
                ;;
            2)
                delete_site
                ;;
            3)
                list_sites
                ;;
            4)
                return
                ;;
        esac
    done
}

# 创建默认服务器配置
create_default_server() {
    local conf_file="/usr/local/openresty/nginx/conf/conf.d/default.conf"
    mkdir -p "/usr/local/openresty/nginx/conf/conf.d"
    
    cat > "$conf_file" << 'EOF'
# 默认服务器配置
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /usr/local/openresty/nginx/html;
    
    access_log /usr/local/openresty/nginx/logs/default_access.log;
    error_log /usr/local/openresty/nginx/logs/default_error.log;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
}

# 更新nginx.conf配置
update_nginx_conf() {
    local nginx_conf="/usr/local/openresty/nginx/conf/nginx.conf"
    
    # 备份原配置
    cp "$nginx_conf" "$nginx_conf.bak"
    
    # 创建新的nginx.conf
    cat > "$nginx_conf" << 'EOF'
user www-data;
worker_processes auto;
error_log logs/error.log;
pid logs/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log logs/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;
    
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # SSL配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # 先加载站点配置
    include sites-enabled/*.conf;
    # 后加载默认配置
    include conf.d/*.conf;
}
EOF
    
    # 测试配置
    if ! openresty -t; then
        echo -e "${RED}配置测试失败，还原配置${NC}"
        mv "$nginx_conf.bak" "$nginx_conf"
        return 1
    fi
    
    systemctl reload openresty
    return 0
}

# 修改create_site函数
create_site() {
    local domain=$1
    local conf_file="/usr/local/openresty/nginx/conf/sites-available/${domain}.conf"
    local root_dir="/usr/local/openresty/nginx/html/${domain}"
    
    # 创建目录
    mkdir -p "$root_dir"
    
    # 创建站点配置
    cat > "$conf_file" << EOF
# 站点配置：$domain
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    # 设置网站根目录
    root $root_dir;
    index index.html index.htm index.php;
    
    # 日志配置
    access_log /usr/local/openresty/nginx/logs/${domain}_access.log main;
    error_log /usr/local/openresty/nginx/logs/${domain}_error.log;
    
    # 主要配置
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
    
    # 创建软链接
    ln -sf "$conf_file" "/usr/local/openresty/nginx/conf/sites-enabled/"
    
    # 创建默认页面
    cat > "$root_dir/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$domain - Welcome</title>
    <style>
        :root {
            --primary-color: #2563eb;
            --secondary-color: #3b82f6;
            --success-color: #059669;
            --text-primary: #1f2937;
            --text-secondary: #4b5563;
            --bg-primary: #f3f4f6;
            --bg-secondary: #ffffff;
            --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: var(--text-primary);
            background: var(--bg-primary);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: clamp(1rem, 5vw, 3rem);
        }
        
        .container {
            background: var(--bg-secondary);
            border-radius: 1rem;
            box-shadow: var(--shadow-lg);
            padding: clamp(1.5rem, 5vw, 3rem);
            width: min(100%, 1200px);
            margin: 0 auto;
            position: relative;
            overflow: hidden;
        }
        
        .container::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
        }
        
        .header {
            text-align: center;
            margin-bottom: clamp(2rem, 5vw, 4rem);
        }
        
        .logo {
            width: clamp(60px, 15vw, 100px);
            height: auto;
            margin-bottom: 1.5rem;
            filter: drop-shadow(var(--shadow-sm));
        }
        
        h1 {
            color: var(--text-primary);
            font-size: clamp(1.5rem, 5vw, 2.5rem);
            font-weight: 700;
            margin-bottom: 0.5rem;
        }
        
        .subtitle {
            color: var(--text-secondary);
            font-size: clamp(1rem, 3vw, 1.25rem);
        }
        
        .grid {
            display: grid;
            gap: clamp(1rem, 3vw, 2rem);
            grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr));
            margin: clamp(1.5rem, 4vw, 3rem) 0;
        }
        
        .card {
            background: var(--bg-primary);
            border-radius: 0.75rem;
            padding: clamp(1.25rem, 3vw, 2rem);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            box-shadow: var(--shadow-sm);
        }
        
        .card:hover {
            transform: translateY(-4px);
            box-shadow: var(--shadow-md);
        }
        
        .status-card {
            border-left: 4px solid var(--success-color);
            background: var(--bg-secondary);
            padding: clamp(1rem, 3vw, 2rem);
            margin: clamp(1.5rem, 4vw, 3rem) 0;
            border-radius: 0.75rem;
            box-shadow: var(--shadow-sm);
        }
        
        .card h3 {
            color: var(--primary-color);
            font-size: clamp(1.1rem, 3vw, 1.25rem);
            margin-bottom: 0.75rem;
        }
        
        .card p {
            color: var(--text-secondary);
            font-size: clamp(0.9rem, 2vw, 1rem);
        }
        
        .info-section {
            background: var(--bg-primary);
            border-radius: 0.75rem;
            padding: clamp(1.25rem, 3vw, 2rem);
            margin-top: clamp(1.5rem, 4vw, 3rem);
        }
        
        .info-section p {
            margin: 0.75rem 0;
            color: var(--text-secondary);
            font-size: clamp(0.9rem, 2vw, 1rem);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .info-section strong {
            color: var(--primary-color);
            font-weight: 600;
        }
        
        .footer {
            text-align: center;
            margin-top: clamp(2rem, 5vw, 4rem);
            color: var(--text-secondary);
            font-size: clamp(0.8rem, 2vw, 0.9rem);
        }
        
        @media (prefers-color-scheme: dark) {
            :root {
                --primary-color: #3b82f6;
                --secondary-color: #60a5fa;
                --success-color: #059669;
                --text-primary: #f3f4f6;
                --text-secondary: #d1d5db;
                --bg-primary: #111827;
                --bg-secondary: #1f2937;
            }
        }

        @media (max-width: 640px) {
            .grid {
                grid-template-columns: 1fr;
            }
            
            .card {
                padding: 1.25rem;
            }
            
            .status-card {
                margin: 1.5rem 0;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>$domain</h1>
            <p class="subtitle">站点配置成功</p>
        </header>
        
        <div class="status-card">
            <h2>✓ 站点已激活</h2>
            <p>您现在可以上传您的网站文件了。</p>
        </div>
        
        <div class="info-section">
            <p>🖥️ 站点信息</p>
            <p>• 域名：<strong>$domain</strong></p>
            <p>• 网站目录：<strong>$root_dir</strong></p>
            <p>• 配置文件：<strong>$conf_file</strong></p>
        </div>
    </div>
</body>
</html>
EOF
    
    # 设置权限
    chown -R www-data:www-data "$root_dir"
    chmod -R 755 "$root_dir"
    find "$root_dir" -type f -exec chmod 644 {} \;
    find "$root_dir" -type d -exec chmod 755 {} \;
    
    # 测试并重载配置
    if openresty -t; then
        systemctl reload openresty
        echo -e "${GREEN}站点 $domain 创建成功！${NC}"
        echo -e "网站根目录: ${BLUE}$root_dir${NC}"
        echo -e "请将您的网站文件上传到此目录"
        echo -e "确保文件权限正确：目录 755，文件 644"
        echo -e "\n配置信息："
        echo -e "域名: ${GREEN}$domain${NC}"
        echo -e "配置文件: ${BLUE}$conf_file${NC}"
        echo -e "访问日志: ${BLUE}/usr/local/openresty/nginx/logs/${domain}_access.log${NC}"
        echo -e "错误日志: ${BLUE}/usr/local/openresty/nginx/logs/${domain}_error.log${NC}"
    else
        echo -e "${RED}配置测试失败${NC}"
        rm -f "$conf_file"
        rm -rf "$root_dir"
    fi
}

# 删除站点
delete_site() {
    local sites_dir="/usr/local/openresty/nginx/conf/sites-available"
    local sites=($(ls $sites_dir/*.conf 2>/dev/null | xargs -n1 basename 2>/dev/null))
    
    if [ ${#sites[@]} -eq 0 ]; then
        echo -e "${RED}没有可用的站点${NC}"
        echo "1. 返回上级菜单"
        read -p "请按1返回: " choice
        return
    fi
    
    echo "可用站点:"
    for i in "${!sites[@]}"; do
        echo "$((i+1)). ${sites[$i]%.conf}"
    done
    echo "$((${#sites[@]}+1)). 返回上级菜单"
    
    read -p "选择要删除的站点编号: " choice
    if [ "$choice" = "$((${#sites[@]}+1))" ]; then
        return
    fi
    
    if [ "$choice" -gt 0 ] && [ "$choice" -le "${#sites[@]}" ]; then
        local site=${sites[$((choice-1))]}
        local domain=${site%.conf}
        
        echo "确认删除站点 $domain?"
        echo "1. 确认删除"
        echo "2. 返回上级菜单"
        read -p "请输入选项 [1-2]: " confirm
        case $confirm in
            1)
                rm -f "$sites_dir/$site"
                rm -f "/usr/local/openresty/nginx/conf/sites-enabled/$site"
                rm -rf "/usr/local/openresty/nginx/html/$domain"
                systemctl reload openresty
                echo -e "${GREEN}站点已删除${NC}"
                ;;
            2)
                return
                ;;
            *)
                echo -e "${RED}无效的选择，返回上级菜单${NC}"
                return
                ;;
        esac
    else
        echo -e "${RED}无效的选择${NC}"
        return
    fi
}

# 列出所有站点
list_sites() {
    echo -e "\n${GREEN}=== 站点列表 ===${NC}"
    local sites_dir="/usr/local/openresty/nginx/conf/sites-available"
    local count=0
    
    for conf in "$sites_dir"/*.conf; do
        if [ -f "$conf" ]; then
            local domain=$(basename "$conf" .conf)
            echo -e "\n站点: ${GREEN}$domain${NC}"
            echo -e "配置文件: ${BLUE}$conf${NC}"
            echo -e "网站目录: ${BLUE}/usr/local/openresty/nginx/html/$domain${NC}"
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}暂无站点配置${NC}"
    fi
    
    echo -e "\n1. 返回上级菜单"
    read -p "请按1返回: " choice
    return
}

# 添加自动热重载
setup_auto_reload() {
    # 创建配置监听脚本
    cat > "/usr/local/bin/openresty-auto-reload.sh" << 'EOF'
#!/bin/bash
LAST_RELOAD=0
MIN_INTERVAL=5

while true; do
    CURRENT_TIME=$(date +%s)
    if openresty -t &>/dev/null; then
        if [ $((CURRENT_TIME - LAST_RELOAD)) -ge $MIN_INTERVAL ]; then
            systemctl reload openresty
            LAST_RELOAD=$CURRENT_TIME
        fi
    fi
    sleep 2
done
EOF

    chmod +x "/usr/local/bin/openresty-auto-reload.sh"

    # 创建systemd服务
    cat > "/etc/systemd/system/openresty-auto-reload.service" << EOF
[Unit]
Description=OpenResty Auto Reload Service
After=openresty.service

[Service]
Type=simple
ExecStart=/usr/local/bin/openresty-auto-reload.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable openresty-auto-reload
    systemctl start openresty-auto-reload
}

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root权限运行此脚本${NC}"
    exit 1
fi

# 主程序
check_system
check_openresty
main_menu
