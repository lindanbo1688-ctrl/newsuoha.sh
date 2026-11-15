#!/bin/bash
# onekey suoha - Argo Only Edition (默认+优选 VLESS/Trojan，短命名，IP地区前缀，systemd开机自启)

export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

ACTION="${1:-}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function show_progress() {
    local pct=$1
    local msg="$2"
    local width=32
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar_filled=""
    local bar_empty=""

    if [ $filled -gt 0 ]; then
        bar_filled=$(printf "%${filled}s" | tr ' ' '=')
    fi
    if [ $empty -gt 0 ]; then
        bar_empty=$(printf "%${empty}s" | tr ' ' '.')
    fi

    printf "\r\033[K${CYAN}[${GREEN}${bar_filled}${NC}${bar_empty}${CYAN}] ${YELLOW}%3d%%${NC} - %s" "$pct" "$msg"
}

linux_os=("Debian" "Ubuntu" "CentOS" "Fedora" "Alpine")
linux_update=("apt update" "apt update" "yum -y update" "yum -y update" "apk update")
linux_install=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
n=0
OS_NAME=$(grep -i PRETTY_NAME /etc/os-release 2>/dev/null | cut -d \" -f2 | awk '{print $1}')

for i in "${linux_os[@]}"; do
    if [ "$i" == "$OS_NAME" ]; then
        break
    else
        n=$((n+1))
    fi
done

if [ $n -eq 5 ]; then
    n=0
fi

# 针对 1080P / 4K 高码率视频流媒体进行纯净安全的 TCP & UDP 内核级网络优化 (不干扰端口段与 TLS 握手)
function optimize_network_4k() {
    show_progress 2 "正在执行 TCP/UDP 1080P/4K 流媒体与 BBR 内核级网络优化..."

    modprobe tcp_bbr >/dev/null 2>&1
    ulimit -n 1048576 >/dev/null 2>&1

    local total_mem_mb
    total_mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    local max_buf=33554432
    local def_buf=1048576
    if [[ -n "$total_mem_mb" && "$total_mem_mb" -lt 512 ]]; then
        max_buf=8388608
        def_buf=262144
    fi

    if [ -w /etc ] && [ -w /proc/sys ]; then
        mkdir -p /etc/sysctl.d >/dev/null 2>&1
        cat > /etc/sysctl.d/99-suoha-4k.conf <<EOF
# === OneKey Suoha 1080P / 4K Video Streaming TCP & UDP Optimization ===
# 1. BBR 拥塞控制与 FQ 队列调度
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 2. TCP / UDP 读写缓冲区窗口扩容 (适配 1080P / 4K 60fps 高码率视频流)
net.core.rmem_default = ${def_buf}
net.core.wmem_default = ${def_buf}
net.core.rmem_max = ${max_buf}
net.core.wmem_max = ${max_buf}
net.ipv4.tcp_rmem = 4096 87380 ${max_buf}
net.ipv4.tcp_wmem = 4096 65536 ${max_buf}

# 3. UDP / QUIC (Hysteria2 / TUIC v5) 突发高码率队列防丢包
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192

# 4. 视频暂停恢复防降速 (保持安全默认握手机制，不抢占监听端口段)
net.ipv4.tcp_slow_start_after_idle = 0
EOF
        sysctl -p /etc/sysctl.d/99-suoha-4k.conf >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1
    fi
}

install_deps() {
    local deps=("unzip" "curl" "python3" "openssl" "tar" "jq")
    local need_update=0
    for dep in "${deps[@]}"; do
        if [ -z "$(type -P "$dep")" ]; then
            need_update=1
            break
        fi
    done

    if [ $need_update -eq 1 ]; then
        show_progress 5 "正在更新系统软件源..."
        ${linux_update[$n]} >/dev/null 2>&1
        local total_deps=${#deps[@]}
        local idx=0
        for dep in "${deps[@]}"; do
            idx=$((idx+1))
            local step_pct=$((5 + idx * 7 / total_deps))
            if [ -z "$(type -P "$dep")" ]; then
                show_progress $step_pct "正在安装依赖组件: ${dep}..."
                ${linux_install[$n]} "$dep" >/dev/null 2>&1
            fi
        done
    fi
    show_progress 12 "系统基础依赖检查完成"
}

function get_server_ip() {
    local ip=""
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    if [[ -z "$ip" || "$ip" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
        ip=$(curl -s4 --connect-timeout 3 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | awk -F= '/ip/{print $2}')
    fi
    if [ -z "$ip" ]; then
        ip=$(curl -s4 --connect-timeout 3 https://ipv4.icanhazip.com 2>/dev/null | tr -d '\n\r ')
    fi
    if [ -z "$ip" ]; then
        ip=$(curl -s4 --connect-timeout 3 https://api.ip.sb/ip 2>/dev/null | tr -d '\n\r ')
    fi
    echo "$ip"
}

function get_server_ipv6() {
    local ip6=""
    ip6=$(curl -s6 --connect-timeout 3 https://api64.ipify.org 2>/dev/null | tr -d '\n\r ')
    if [ -z "$ip6" ]; then
        ip6=$(curl -s6 --connect-timeout 3 https://ipv6.icanhazip.com 2>/dev/null | tr -d '\n\r ')
    fi
    if [ -z "$ip6" ]; then
        ip6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1 | tr -d '\n\r ')
    fi
    echo "$ip6"
}

# 按公网 IP 识别两位国家码（TW/JP/HK/US...），失败则 UN
function detect_region_code() {
    local ip="$1"
    local code=""

    # 1) Cloudflare trace（快且稳）
    code=$(curl -s4 --connect-timeout 3 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | awk -F= '/^loc=/{print $2}' | tr -d '\n\r ')
    code=$(echo "$code" | tr 'a-z' 'A-Z')
    if [[ "$code" =~ ^[A-Z]{2}$ ]]; then
        echo "$code"
        return 0
    fi

    # 2) 按 IP 查询
    if [ -n "$ip" ]; then
        code=$(curl -s4 --connect-timeout 4 "https://ipapi.co/${ip}/country/" 2>/dev/null | tr -d '\n\r ')
        code=$(echo "$code" | tr 'a-z' 'A-Z')
        if [[ "$code" =~ ^[A-Z]{2}$ ]]; then
            echo "$code"
            return 0
        fi
        code=$(curl -s4 --connect-timeout 4 "https://ipinfo.io/${ip}/country" 2>/dev/null | tr -d '\n\r ')
        code=$(echo "$code" | tr 'a-z' 'A-Z')
        if [[ "$code" =~ ^[A-Z]{2}$ ]]; then
            echo "$code"
            return 0
        fi
    fi

    echo "UN"
}

function open_firewall_port() {
    local port="$1"
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "${port}/tcp" >/dev/null 2>&1
            ufw allow "${port}/udp" >/dev/null 2>&1
        fi
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld 2>/dev/null; then
            firewall-cmd --zone=public --add-port="${port}/tcp" >/dev/null 2>&1
            firewall-cmd --zone=public --add-port="${port}/udp" >/dev/null 2>&1
        fi
    fi
    if command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --dport "${port}" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "${port}" -j ACCEPT >/dev/null 2>&1
        iptables -C INPUT -p udp --dport "${port}" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "${port}" -j ACCEPT >/dev/null 2>&1
    fi
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -C INPUT -p tcp --dport "${port}" -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p tcp --dport "${port}" -j ACCEPT >/dev/null 2>&1
        ip6tables -C INPUT -p udp --dport "${port}" -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p udp --dport "${port}" -j ACCEPT >/dev/null 2>&1
    fi
}

function get_or_create_sub_port() {
    local port_file="/etc/suoha_sub_port"
    local port=""
    if [ -f "$port_file" ]; then
        port=$(cat "$port_file" | tr -d '\n\r ')
    fi
    if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
        port=$((RANDOM%10000+25000))
        echo "$port" > "$port_file"
    fi
    open_firewall_port "$port"
    echo "$port"
}

function safe_kill_pidfile() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local target_pid
        target_pid=$(tr -d ' \n\r' < "$pid_file")
        if [[ "$target_pid" =~ ^[0-9]+$ ]] && [ "$target_pid" != "$$" ] && [ "$target_pid" != "$PPID" ]; then
            kill -9 "$target_pid" >/dev/null 2>&1
        fi
        rm -f "$pid_file"
    fi
}

function start_sub_server() {
    local web_dir="$1"
    local port="$2"

    safe_kill_pidfile "/opt/suoha_quick/sub_http.pid"
    if command -v fuser >/dev/null 2>&1; then
        fuser -k "${port}/tcp" >/dev/null 2>&1
    fi
    sleep 0.3

    if [ -x "$(command -v python3)" ]; then
        nohup python3 -m http.server "$port" --bind :: --directory "$web_dir" >/dev/null 2>&1 &
        echo $! > /opt/suoha_quick/sub_http.pid
    fi
}

function sync_to_static_web() {
    local src_dir="$1"
    local static_dir="/var/www/suoha_sub"
    rm -rf "$static_dir" >/dev/null 2>&1
    mkdir -p "$static_dir" >/dev/null 2>&1
    [ -f "${src_dir}/nodes.txt" ] && cp -f "${src_dir}/nodes.txt" "${static_dir}/nodes.txt" 2>/dev/null
    [ -f "${src_dir}/sub.txt" ] && cp -f "${src_dir}/sub.txt" "${static_dir}/sub.txt" 2>/dev/null
    [ -f "${src_dir}/clash.yaml" ] && cp -f "${src_dir}/clash.yaml" "${static_dir}/clash.yaml" 2>/dev/null
    [ -f "${src_dir}/surge.conf" ] && cp -f "${src_dir}/surge.conf" "${static_dir}/surge.conf" 2>/dev/null
}

function stop_all_services() {
    safe_kill_pidfile "/opt/suoha_quick/singbox.pid"
    safe_kill_pidfile "/opt/suoha_quick/cf_main.pid"
    safe_kill_pidfile "/opt/suoha_quick/cf_vl.pid"
    safe_kill_pidfile "/opt/suoha_quick/cf_tr.pid"
    safe_kill_pidfile "/opt/suoha_quick/argo_router.pid"
    safe_kill_pidfile "/opt/suoha_quick/snell.pid"
    safe_kill_pidfile "/opt/suoha_quick/snell_v6.pid"
    safe_kill_pidfile "/opt/suoha_quick/sub_http.pid"

    if command -v killall >/dev/null 2>&1; then
        killall -9 sing-box cloudflared-linux snell-server snell-server-v6 >/dev/null 2>&1
    else
        for bin_name in sing-box cloudflared-linux snell-server snell-server-v6; do
            for pid in $(pidof "$bin_name" 2>/dev/null); do
                if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
                    kill -9 "$pid" >/dev/null 2>&1
                fi
            done
        done
    fi
}

function write_boot_scripts() {
    cat > /opt/suoha_quick/boot_stop.sh <<'EOS'
#!/bin/bash
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
safe_kill() {
  local f="$1"
  if [ -f "$f" ]; then
    local p; p=$(tr -d ' \n\r' < "$f")
    if [[ "$p" =~ ^[0-9]+$ ]]; then kill -9 "$p" >/dev/null 2>&1; fi
    rm -f "$f"
  fi
}
safe_kill /opt/suoha_quick/singbox.pid
safe_kill /opt/suoha_quick/cf_main.pid
safe_kill /opt/suoha_quick/argo_router.pid
safe_kill /opt/suoha_quick/snell.pid
safe_kill /opt/suoha_quick/snell_v6.pid
safe_kill /opt/suoha_quick/sub_http.pid
killall -9 sing-box cloudflared-linux snell-server 2>/dev/null || true
exit 0
EOS

    cat > /opt/suoha_quick/boot_start.sh <<'EOS'
#!/bin/bash
# 开机/手动恢复：用已有配置拉起服务，不重新生成 UUID
set -e
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
DIR=/opt/suoha_quick
cd "$DIR" || exit 1

if [ ! -x "$DIR/sing-box" ] || [ ! -f "$DIR/singbox.json" ]; then
  echo "suoha: 未找到已安装配置，请先执行安装"
  exit 1
fi

bash "$DIR/boot_stop.sh" >/dev/null 2>&1 || true
sleep 0.5

# 1) sing-box（Reality/HY2/TUIC/SS 等，UUID 不变）
nohup "$DIR/sing-box" run -c "$DIR/singbox.json" >"$DIR/singbox.log" 2>&1 &
echo $! > "$DIR/singbox.pid"

# 2) Argo 本地分流
if [ -f "$DIR/argo_router.py" ]; then
  nohup python3 "$DIR/argo_router.py" >/dev/null 2>&1 &
  echo $! > "$DIR/argo_router.pid"
fi

# 3) Snell
if [ -x "$DIR/snell-server" ] && [ -f "$DIR/snell.conf" ]; then
  nohup "$DIR/snell-server" -c "$DIR/snell.conf" >"$DIR/snell.log" 2>&1 &
  echo $! > "$DIR/snell.pid"
fi

# 4) Cloudflare Quick Tunnel（临时域名每次可能变化，但 UUID/路径不变）
ENTRY_PORT=$(tr -d ' \n\r' < "$DIR/argo_entry_port" 2>/dev/null || true)
EDGE_IP=$(tr -d ' \n\r' < "$DIR/edge_ip_version" 2>/dev/null || echo 4)
OLD_DOMAIN=$(tr -d ' \n\r' < "$DIR/argo_domain.txt" 2>/dev/null || true)
if [ -x "$DIR/cloudflared-linux" ] && [[ "$ENTRY_PORT" =~ ^[0-9]+$ ]]; then
  rm -f "$DIR/argo_main.log"
  nohup "$DIR/cloudflared-linux" tunnel --url "http://127.0.0.1:${ENTRY_PORT}" --no-autoupdate --edge-ip-version "$EDGE_IP" --protocol http2 >"$DIR/argo_main.log" 2>&1 &
  echo $! > "$DIR/cf_main.pid"
  NEW_DOMAIN=""
  for i in $(seq 1 40); do
    NEW_DOMAIN=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" "$DIR/argo_main.log" 2>/dev/null | head -n1 | awk -F// '{print $2}')
    [ -n "$NEW_DOMAIN" ] && break
    if [ "$i" -eq 25 ]; then
      kill -9 "$(tr -d ' \n\r' < "$DIR/cf_main.pid" 2>/dev/null)" 2>/dev/null || true
      nohup "$DIR/cloudflared-linux" tunnel --url "http://127.0.0.1:${ENTRY_PORT}" --no-autoupdate --edge-ip-version "$EDGE_IP" --protocol quic >"$DIR/argo_main.log" 2>&1 &
      echo $! > "$DIR/cf_main.pid"
    fi
    sleep 1
  done
  if [ -n "$NEW_DOMAIN" ]; then
    if [ -n "$OLD_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
      for f in nodes.txt clash.yaml v2ray.txt surge.conf; do
        [ -f "$DIR/$f" ] && sed -i "s/${OLD_DOMAIN}/${NEW_DOMAIN}/g" "$DIR/$f" 2>/dev/null || true
      done
    fi
    echo "$NEW_DOMAIN" > "$DIR/argo_domain.txt"
    if [ -f "$DIR/nodes.txt" ]; then
      if command -v base64 >/dev/null 2>&1; then
        if base64 -w 0 /dev/null >/dev/null 2>&1; then
          base64 -w 0 "$DIR/nodes.txt" > "$DIR/sub.txt"
        else
          base64 "$DIR/nodes.txt" | tr -d '\n' > "$DIR/sub.txt"
        fi
      fi
    fi
    # 同步静态订阅目录
    mkdir -p /var/www/suoha_sub
    for f in nodes.txt sub.txt clash.yaml surge.conf; do
      [ -f "$DIR/$f" ] && cp -f "$DIR/$f" "/var/www/suoha_sub/$f" 2>/dev/null || true
    done
  fi
fi

# 5) 订阅 HTTP 服务
SUB_PORT=$(tr -d ' \n\r' < /etc/suoha_sub_port 2>/dev/null || true)
if [[ "$SUB_PORT" =~ ^[0-9]+$ ]] && [ -d /var/www/suoha_sub ]; then
  if command -v fuser >/dev/null 2>&1; then fuser -k "${SUB_PORT}/tcp" >/dev/null 2>&1 || true; fi
  nohup python3 -m http.server "$SUB_PORT" --bind :: --directory /var/www/suoha_sub >/dev/null 2>&1 &
  echo $! > "$DIR/sub_http.pid"
fi

echo "suoha: 服务已恢复（UUID 不变；若 Argo 域名变更已自动改写订阅）"
exit 0
EOS

    chmod +x /opt/suoha_quick/boot_start.sh /opt/suoha_quick/boot_stop.sh
}

function install_systemd_autostart() {
    # $1 = enable-only | restart
    local mode="${1:-enable-only}"
    write_boot_scripts
    cat > /etc/systemd/system/suoha.service <<'EOF'
[Unit]
Description=Suoha Quick Proxy Stack (sing-box + Argo + Snell)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/suoha_quick/boot_start.sh
ExecStop=/opt/suoha_quick/boot_stop.sh
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable suoha.service >/dev/null 2>&1 || true
    if [ "$mode" = "restart" ]; then
        systemctl restart suoha.service >/dev/null 2>&1 || systemctl start suoha.service >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}已启用开机自启: systemctl status suoha --no-pager${NC}"
}

function restore_services_only() {
    if [ ! -f /opt/suoha_quick/singbox.json ]; then
        echo -e "${RED}尚未安装，请先选 1 安装。${NC}"
        return 1
    fi
    install_systemd_autostart restart
    echo -e "${GREEN}已按原配置恢复服务（不重装、不换 UUID）${NC}"
    echo -e "${YELLOW}说明: Argo 临时域名重启后可能变化，脚本会自动改写订阅；直连节点 UUID 不变。${NC}"
    echo "查看: systemctl status suoha --no-pager"
    [ -f /opt/suoha_quick/argo_domain.txt ] && echo "当前 Argo: $(cat /opt/suoha_quick/argo_domain.txt)"
}

function uninstall_all() {
    show_progress 20 "正在停止运行中的全协议代理进程..."
    systemctl disable --now suoha.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/suoha.service
    systemctl daemon-reload >/dev/null 2>&1 || true
    if [ -x /opt/suoha_quick/boot_stop.sh ]; then
        bash /opt/suoha_quick/boot_stop.sh >/dev/null 2>&1 || true
    fi
    stop_all_services
    sleep 0.5
    show_progress 60 "正在清理 HTTP 订阅守护进程..."
    if [ -f "/etc/suoha_sub_port" ]; then
        local old_port
        old_port=$(tr -d ' \n\r' < /etc/suoha_sub_port)
        if [[ "$old_port" =~ ^[0-9]+$ ]] && command -v fuser >/dev/null 2>&1; then
            fuser -k "${old_port}/tcp" >/dev/null 2>&1
        fi
    fi
    sleep 0.5
    show_progress 90 "正在删除配置文件、内核调优与证书目录..."
    rm -rf /opt/suoha /opt/suoha_quick /etc/suoha_sub_port /var/www/suoha_sub /usr/bin/suoha /etc/sysctl.d/99-suoha-4k.conf
    sysctl --system >/dev/null 2>&1
    show_progress 100 "卸载清理完成！"
    echo -e "\n所有梭哈全协议服务、内核网络调优及订阅文件已彻底清理完成。"
    exit 0
}

function show_main_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}   梭哈全协议一键脚本 主菜单${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "  ${GREEN}1)${NC} 安装 / 重新梭哈（会换新 UUID）"
    echo -e "  ${GREEN}2)${NC} 恢复服务 / 启用开机自启（不换 UUID）"
    echo -e "  ${YELLOW}3)${NC} 卸载（停止进程并清理文件）"
    echo -e "  ${CYAN}4)${NC} 查看当前节点信息"
    echo -e "  ${RED}0)${NC} 退出"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}提示: 安装后会注册 systemd 开机自启；重启后 UUID 不变${NC}"
    echo -e "${YELLOW}命令行: bash suoha.sh install | start | uninstall${NC}"
    echo
    read -rp "请选择 [0-4]，默认 1: " choice
    choice="${choice:-1}"
    case "$choice" in
        1|install|i|I)
            quicktunnel_all_in_one
            ;;
        2|start|restore|r|R)
            restore_services_only
            ;;
        3|uninstall|u|U)
            echo
            read -rp "确认卸载并删除 /opt/suoha_quick 等全部数据？[y/N]: " confirm
            if [[ "${confirm}" =~ ^[Yy]$ ]]; then
                uninstall_all
            else
                echo "已取消卸载"
            fi
            ;;
        4|info|v|V)
            if [ -f /opt/suoha_quick/v2ray.txt ]; then
                clear
                cat /opt/suoha_quick/v2ray.txt
            else
                echo -e "${RED}未找到节点信息，请先安装。${NC}"
            fi
            ;;
        0|q|Q|exit)
            echo "已退出"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            exit 1
            ;;
    esac
}

function quicktunnel_all_in_one() {
    clear
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${GREEN}   一键部署启动中 (仅 Argo 默认 + 优选：VLESS/Trojan)${NC}"
    echo -e "${CYAN}==================================================================${NC}\n"

    show_progress 1 "初始化运行环境并彻底清空旧进程与历史文件..."
    stop_all_services
    optimize_network_4k
    install_deps

    rm -rf /opt/suoha /opt/suoha_quick /var/www/suoha_sub
    mkdir -p /opt/suoha_quick/cert >/dev/null 2>&1
    cd /opt/suoha_quick || exit 1

    # 1. 架构识别与核心下载
    local arch_sb=""
    local arch_cf=""
    local arch_snell=""

    case "$(uname -m)" in
        x86_64 | x64 | amd64 )
            arch_sb="linux-amd64"
            arch_cf="linux-amd64"
            arch_snell="linux-amd64"
            ;;
        i386 | i686 )
            arch_sb="linux-386"
            arch_cf="linux-386"
            arch_snell="linux-i386"
            ;;
        armv8 | arm64 | aarch64 )
            arch_sb="linux-arm64"
            arch_cf="linux-arm64"
            arch_snell="linux-aarch64"
            ;;
        armv7l )
            arch_sb="linux-armv7"
            arch_cf="linux-arm"
            arch_snell="linux-armv7l"
            ;;
        * )
            echo -e "\n${RED}当前架构 $(uname -m) 暂不支持！${NC}"
            exit 1
            ;;
    esac

    show_progress 15 "正在获取官方 Sing-box 稳定版核心..."
    local sb_version
    sb_version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$sb_version" ]; then
        sb_version="1.12.12"
    fi

    show_progress 22 "正在下载官方 Sing-box v${sb_version} 主力核心..."
    curl -sL "https://github.com/SagerNet/sing-box/releases/download/v${sb_version}/sing-box-${sb_version}-${arch_sb}.tar.gz" -o sb.tar.gz
    tar -xzf sb.tar.gz >/dev/null 2>&1
    mv "sing-box-${sb_version}-${arch_sb}/sing-box" /opt/suoha_quick/sing-box 2>/dev/null
    rm -rf "sing-box-${sb_version}-${arch_sb}" sb.tar.gz

    show_progress 34 "正在下载 Cloudflare Argo 隧道组件..."
    curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${arch_cf}" -o /opt/suoha_quick/cloudflared-linux

    show_progress 44 "跳过 Snell 下载（仅保留默认/优选 Argo 节点）..."
    chmod +x /opt/suoha_quick/sing-box /opt/suoha_quick/cloudflared-linux 2>/dev/null

    if [ ! -x /opt/suoha_quick/sing-box ] || [ ! -x /opt/suoha_quick/cloudflared-linux ]; then
        echo -e "\n${RED}核心文件下载失败，请检查服务器网络连接（GitHub 访问是否正常）！${NC}"
        exit 1
    fi

    # 2. 探测服务器公网 IPv4 与 IPv6
    show_progress 48 "正在探测服务器双栈公网 IP..."
    local server_ip
    server_ip=$(get_server_ip)
    local server_ipv6
    server_ipv6=$(get_server_ipv6)

    # 3. 仅部署 Argo「默认 + 优选」节点（不再生成 Reality/HY2/TUIC/AnyTLS/Snell/SS）
    show_progress 52 "仅启用 Argo 默认/优选节点，跳过直连协议..."

    # 4. 分配凭证与本机 Argo 分流端口（不对公网随机开高位端口）
    local uuid
    uuid=$(cat /proc/sys/kernel/random/uuid)
    local short_id
    short_id=$(echo "$uuid" | awk -F- '{print $1}')
    local urlpath_vless="vl-${short_id}"
    local urlpath_trojan="tr-${short_id}"

    local port_argo_entry=$((RANDOM%10000+11000))
    local port_argo_vl=$((port_argo_entry+1))
    local port_argo_tr=$((port_argo_entry+2))
    echo "${port_argo_entry}" > /opt/suoha_quick/argo_entry_port

    # 5. 生成 Sing-box 配置（仅本机 VLESS-WS + Trojan-WS，供 Argo 反代）
    show_progress 58 "正在写入 Sing-box（仅 Argo 双路径）..."
    cat > /opt/suoha_quick/singbox.json <<EOF
{
  "log": {
    "level": "error",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "argo-vless-in",
      "listen": "127.0.0.1",
      "listen_port": ${port_argo_vl},
      "users": [
        {
          "uuid": "${uuid}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${urlpath_vless}"
      }
    },
    {
      "type": "trojan",
      "tag": "argo-trojan-in",
      "listen": "127.0.0.1",
      "listen_port": ${port_argo_tr},
      "users": [
        {
          "password": "${uuid}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${urlpath_trojan}"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

    show_progress 66 "正在启动 Sing-box 与 Argo 本地分流..."
    nohup /opt/suoha_quick/sing-box run -c /opt/suoha_quick/singbox.json >/opt/suoha_quick/singbox.log 2>&1 &
    local sb_pid=$!
    echo $sb_pid > /opt/suoha_quick/singbox.pid

    # 轻量本地 WebSocket 路径分流守护进程 (单 Argo 域名按请求路径分发 /vl-xxx 与 /tr-xxx)
    cat > /opt/suoha_quick/argo_router.py <<EOF
import asyncio

async def relay(reader, writer):
    try:
        while True:
            chunk = await reader.read(32768)
            if not chunk:
                break
            writer.write(chunk)
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass

async def handle_client(client_reader, client_writer):
    try:
        head = await asyncio.wait_for(client_reader.readuntil(b"\r\n\r\n"), timeout=10.0)
        first_line = head.split(b"\r\n", 1)[0]
        target_port = ${port_argo_vl}
        if b"/${urlpath_trojan}" in first_line:
            target_port = ${port_argo_tr}
        upstream_reader, upstream_writer = await asyncio.open_connection("127.0.0.1", target_port)
        upstream_writer.write(head)
        await upstream_writer.drain()
        await asyncio.gather(
            relay(client_reader, upstream_writer),
            relay(upstream_reader, client_writer)
        )
    except Exception:
        try:
            client_writer.close()
        except Exception:
            pass

async def main():
    server = await asyncio.start_server(handle_client, "127.0.0.1", ${port_argo_entry})
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
EOF
    nohup python3 /opt/suoha_quick/argo_router.py >/dev/null 2>&1 &
    echo $! > /opt/suoha_quick/argo_router.pid

    local snell_installed=0
    local snell_status="已跳过（仅默认/优选）"
    local snell_psk=""

    local sb_status="运行正常 (PID:${sb_pid})"
    if ! kill -0 "$sb_pid" 2>/dev/null; then
        sb_status="异常: $(cat /opt/suoha_quick/singbox.log 2>/dev/null | tr '\n' ' ')"
    fi

    # 6. 拉起单个 Cloudflare Argo 隧道 (双协议共用同一 Argo 域名)
    show_progress 70 "正在获取机房归属并建立单 Argo 双路径隧道..."
    local ips=4
    if [ -z "$server_ip" ] && [ -n "$server_ipv6" ]; then
        ips=6
    fi

    # 节点前缀：按公网 IP 识别国家码（如 TW/JP/HK），不再使用超长 Suoha_Node / 机房串
    local node_tag
    node_tag=$(detect_region_code "$server_ip")
    show_progress 72 "节点地区前缀: ${node_tag}（按 IP 自动识别）"
    echo "${ips}" > /opt/suoha_quick/edge_ip_version
    echo "${port_argo_entry}" > /opt/suoha_quick/argo_entry_port

    show_progress 74 "正在申请 Argo 隧道 (VLESS /${urlpath_vless} + Trojan /${urlpath_trojan})..."
    /opt/suoha_quick/cloudflared-linux tunnel --url "http://127.0.0.1:${port_argo_entry}" --no-autoupdate --edge-ip-version "$ips" --protocol http2 > /opt/suoha_quick/argo_main.log 2>&1 &
    echo $! > /opt/suoha_quick/cf_main.pid

    local wait_sec=0
    local argo_domain=""
    while true; do
        wait_sec=$((wait_sec+1))
        argo_domain=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" /opt/suoha_quick/argo_main.log 2>/dev/null | head -n 1 | awk -F// '{print $2}')

        if [ -n "$argo_domain" ]; then
            rm -f /opt/suoha_quick/argo_main.log
            echo "${argo_domain}" > /opt/suoha_quick/argo_domain.txt
            show_progress 92 "Argo 单域名双路径隧道分配成功: ${argo_domain}"
            break
        fi

        local dynamic_pct=$((74 + wait_sec))
        if [ $dynamic_pct -gt 91 ]; then
            dynamic_pct=91
        fi
        show_progress $dynamic_pct "等待 Argo 分配双协议共用域名 [${wait_sec}s]..."

        if [ $wait_sec -ge 25 ]; then
            wait_sec=0
            safe_kill_pidfile "/opt/suoha_quick/cf_main.pid"
            rm -f /opt/suoha_quick/argo_main.log
            show_progress 75 "Argo 获取超时，正在自动切换 QUIC 重连建立隧道..."
            /opt/suoha_quick/cloudflared-linux tunnel --url "http://127.0.0.1:${port_argo_entry}" --no-autoupdate --edge-ip-version "$ips" --protocol quic > /opt/suoha_quick/argo_main.log 2>&1 &
            echo $! > /opt/suoha_quick/cf_main.pid
            sleep 2
        else
            sleep 1
        fi
    done

    # 7. 生成全协议节点链接与 Clash / Mihomo 配置文件
    show_progress 95 "正在生成全协议 URI 链接与 Clash/Mihomo 聚合配置..."
    > /opt/suoha_quick/nodes.txt
    > /opt/suoha_quick/surge.conf

    cat > /opt/suoha_quick/clash.yaml <<EOF
port: 7890
socks-port: 7891
allow-lan: false
mode: rule
log-level: info
ipv6: true
proxies:
EOF

    local proxy_names=()
    local opt_domains=("cf.090227.xyz" "cloudflare.182682.xyz")
    local opt_labels=("优选1" "优选2")

    local argo_domains=("$argo_domain" "${opt_domains[@]}")
    local argo_labels=("默认" "${opt_labels[@]}")

    # (A) VLESS Argo 节点组 → TW-VLESS-默认 / TW-VLESS-优选1 / TW-VLESS-优选2
    for idx in "${!argo_domains[@]}"; do
        local d="${argo_domains[$idx]}"
        local l="${argo_labels[$idx]}"
        local pname="${node_tag}-VLESS-${l}"
        echo "vless://${uuid}@${d}:443?encryption=none&security=tls&sni=${argo_domain}&type=ws&host=${argo_domain}&path=%2F${urlpath_vless}#${pname}" >> /opt/suoha_quick/nodes.txt
        proxy_names+=("$pname")
        cat >> /opt/suoha_quick/clash.yaml <<EOF
  - name: "${pname}"
    type: vless
    server: ${d}
    port: 443
    uuid: ${uuid}
    cipher: auto
    tls: true
    udp: true
    servername: ${argo_domain}
    network: ws
    ws-opts:
      path: /${urlpath_vless}
      headers:
        Host: ${argo_domain}
EOF
    done

    # (B) Trojan Argo 节点组 → TW-Trojan-默认 / TW-Trojan-优选1 / TW-Trojan-优选2
    for idx in "${!argo_domains[@]}"; do
        local d="${argo_domains[$idx]}"
        local l="${argo_labels[$idx]}"
        local pname="${node_tag}-Trojan-${l}"
        echo "trojan://${uuid}@${d}:443?security=tls&sni=${argo_domain}&type=ws&host=${argo_domain}&path=%2F${urlpath_trojan}#${pname}" >> /opt/suoha_quick/nodes.txt
        proxy_names+=("$pname")
        cat >> /opt/suoha_quick/clash.yaml <<EOF
  - name: "${pname}"
    type: trojan
    server: ${d}
    port: 443
    password: ${uuid}
    udp: true
    sni: ${argo_domain}
    network: ws
    ws-opts:
      path: /${urlpath_trojan}
      headers:
        Host: ${argo_domain}
EOF
    done

    local snell_display_lines=""
    local ss_v6_uri=""

    cat >> /opt/suoha_quick/clash.yaml <<EOF
proxy-groups:
  - name: PROXY
    type: select
    proxies:
EOF

    for pname in "${proxy_names[@]}"; do
        echo "      - \"${pname}\"" >> /opt/suoha_quick/clash.yaml
    done

    cat >> /opt/suoha_quick/clash.yaml <<EOF
rules:
  - MATCH,PROXY
EOF

    show_progress 98 "正在编码 Base64 订阅并拉起本地 HTTP 订阅服务..."
    if [ "$OS_NAME" == "Alpine" ]; then
        base64 /opt/suoha_quick/nodes.txt | tr -d '\n' > /opt/suoha_quick/sub.txt
    else
        base64 -w 0 /opt/suoha_quick/nodes.txt > /opt/suoha_quick/sub.txt
    fi

    local sub_host=""
    if [ -n "$server_ip" ]; then
        sub_host="$server_ip"
    elif [ -n "$server_ipv6" ]; then
        sub_host="[${server_ipv6}]"
    else
        sub_host="$argo_domain"
    fi

    local sub_port
    sub_port=$(get_or_create_sub_port)
    sync_to_static_web "/opt/suoha_quick"
    start_sub_server "/var/www/suoha_sub" "$sub_port"

    local sub_online_url="http://${sub_host}:${sub_port}/sub.txt"
    local clash_online_url="http://${sub_host}:${sub_port}/clash.yaml"

    local cc_active
    cc_active=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "default")
    local qdisc_active
    qdisc_active=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "default")

    cat > /opt/suoha_quick/v2ray.txt <<EOF
======================== Argo 默认/优选节点列表 ========================
[核心运行状态]:
  ├─ 内核网络调优 : 拥塞控制=${cc_active} | 队列=${qdisc_active}
  └─ Sing-box 进程 : ${sb_status}

[模式]: 仅保留默认 + 优选（VLESS/Trojan × 3 = 共 6 个节点）
[单 Argo 共用域名]: ${argo_domain}
  ├─ VLESS  WebSocket 路径: /${urlpath_vless}
  └─ Trojan WebSocket 路径: /${urlpath_trojan}

[节点链接]
$(cat /opt/suoha_quick/nodes.txt)

======================== 说明 ========================
- 已移除 Reality / AnyTLS / HY2 / TUIC / Snell / SS 直连节点
- 客户端看到的端口均为 443（走 Cloudflare），不再占用本机高位公网端口
- Argo 节点 443 也可按需换 CF 其它 TLS 端口: 2053, 2083, 2087, 2096, 8443

======================== 客户端订阅及导入链接 ========================
本机固定订阅服务端口: ${sub_port} (已永久保存，重新梭哈无需重新导入客户端)

1. 通用在线订阅链接 (v2rayN / NekoBox / Shadowrocket / Karing):

${sub_online_url}

2. v2rayN / NekoBox 一键导入链接:
sub://${sub_online_url}

3. Clash Verge Rev / Mihomo 一键导入配置:
clash://install-config?url=${clash_online_url}

4. Clash / Mihomo 在线 YAML 直链:
${clash_online_url}

开机自启: 已注册 systemd 服务 suoha.service（重启后自动恢复，UUID 不变）
手动恢复: 菜单选 2  或  bash $0 start
快捷卸载: 菜单选 3  或  bash $0 uninstall

注意: Argo 临时域名重启后可能变化，开机脚本会自动改写订阅。
客户端若用在线订阅，重启后点「更新订阅」即可。
=====================================================================
EOF

    show_progress 99 "正在注册开机自启..."
    install_systemd_autostart enable-only

    show_progress 100 "全部协议部署完成！"
    sleep 0.6
    clear
    cat /opt/suoha_quick/v2ray.txt
    echo -e "\n所有配置已保存至 /opt/suoha_quick/v2ray.txt，随时执行 cat /opt/suoha_quick/v2ray.txt 查看。"
    echo -e "\n${GREEN}开机自启已开启。重启后无需重装，UUID 不会变。${NC}"
    echo -e "${YELLOW}卸载: 重新运行脚本选 3，或 bash $0 uninstall${NC}"
}

# 入口：支持参数，无参数则进菜单
case "${ACTION}" in
    uninstall|remove|--uninstall|-u)
        uninstall_all
        ;;
    install|--install|-i)
        quicktunnel_all_in_one
        ;;
    start|restore|restart|--start)
        restore_services_only
        ;;
    menu|"")
        show_main_menu
        ;;
    *)
        echo -e "${RED}未知参数: ${ACTION}${NC}"
        echo "用法: bash $0 [install|start|uninstall|menu]"
        exit 1
        ;;
esac
