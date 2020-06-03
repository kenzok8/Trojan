#!/bin/bash
#=================================================
#	System Required: :Debian 9+/Ubuntu 18.04+/Centos 7+
#	Description: Trojan&V2ray&SSR script
#	Version: 1.0.0
#	来自珍妮姐的Trojan-go脚本
# Official document: www.v2ray.com
#=================================================
sh_ver="1.0.0"
#fonts color
RED="\033[0;31m"
NO_COLOR="\033[0m"
GREEN="\033[32m\033[01m"
FUCHSIA="\033[0;35m"
YELLOW="\033[33m"
BLUE="\033[0;36m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
trojan_dir=/etc/trojan
trojan_bin_dir=${trojan_dir}/bin
trojan_conf_dir=${trojan_dir}/conf
trojan_conf_file=${trojan_conf_dir}/server.json
trojan_qr_config_file=${trojan_conf_dir}/qrconfig.json
trojan_systemd_file="/etc/systemd/system/trojan.service"
web_dir="/usr/wwwroot"
nginx_bin_file="/etc/nginx/sbin/nginx"
nginx_conf_dir="/etc/nginx/conf/conf.d"
nginx_conf="${nginx_conf_dir}/default.conf"
nginx_dir="/etc/nginx"
nginx_openssl_src="/usr/local/src"
nginx_systemd_file="/etc/systemd/system/nginx.service"
caddy_bin_dir="/usr/local/bin"
caddy_conf_dir="/etc/caddy"
caddy_conf="${caddy_conf_dir}/Caddyfile"
caddy_systemd_file="/etc/systemd/system/caddy.service"
nginx_version="1.18.0"
openssl_version="1.1.1g"
jemalloc_version="5.2.1"
old_config_status="off"
check_root() {
  [[ $EUID != 0 ]] && echo -e "${Error} ${RedBG} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请执行命令 ${Green_background_prefix}sudo -i${Font_color_suffix} 更换ROOT账号" && exit 1
}
set_SELINUX() {
  if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
  fi
}
check_sys() {
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif cat /etc/issue | grep -q -E -i "debian"; then
    release="debian"
  elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  elif cat /proc/version | grep -q -E -i "debian"; then
    release="debian"
  elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  fi
  bit=`uname -m`
}
sys_cmd(){
  if [[ ${release} == "centos" ]]; then
    cmd="yum"
  else
    cmd="apt"
  fi
}
sucess_or_fail() {
    if [[ 0 -eq $? ]]; then
        echo -e "${Info} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${GreenBG}$1 失败${Font}"
        exit 1
    fi
}
GCE_debian10(){
  echo -e "${Tip}${RedBG}因为谷歌云的debian10抽风，所以需要确认您当前是否是谷歌云的debian10系统吗（Y/n）？"
  echo -e "${Tip}${RedBG}只有谷歌云的debian10系统才填y，其他都填n。如果填错，将直接导致您后面无法科学上网（Y/n）(默认：n)${NO_COLOR}"
  read -rp "请输入:" Yn
  [[ -z ${Yn} ]] && Yn="n"
    case ${Yn} in
    [yY][eE][sS] | [yY])
           is_debian10="y"
        ;;
    *)
        ;;
    esac
}
install_dependency() {
  echo -e "${Info}开始升级系统，需要花费几分钟……"
  ${cmd} update -y
  sucess_or_fail "系统升级"
  echo -e "${Info}开始安装依赖……"
  if [[ ${cmd} == "apt" ]]; then
    apt -y install dnsutils
  else
    yum -y install bind-utils
  fi
  sucess_or_fail "DNS工具包安装"
  ${cmd} -y install wget
  sucess_or_fail "wget包安装"
  ${cmd} -y install unzip
  sucess_or_fail "unzip安装"
  ${cmd} -y install zip
  sucess_or_fail "zip安装"
  ${cmd} -y install curl
  sucess_or_fail "curl安装"
  ${cmd} -y install tar
  sucess_or_fail "tar安装"
  ${cmd} -y install git
  sucess_or_fail "git安装"
  ${cmd} -y install lsof
  sucess_or_fail "lsof安装"
  if [[ ${cmd} == "yum" ]]; then
    yum -y install crontabs
  else
    apt -y install cron
  fi
  sucess_or_fail "定时任务工具安装"
  ${cmd} -y install qrencode
  sucess_or_fail "qrencode安装"
  ${cmd} -y install bzip2
  sucess_or_fail "bzip2安装"
  if [[ ${cmd} == "yum" ]]; then
    yum install -y epel-release
  fi
  sucess_or_fail "epel-release安装"
  if [[ "${cmd}" == "yum" ]]; then
        ${cmd} -y groupinstall "Development tools"
    else
        ${cmd} -y install build-essential
  fi
  sucess_or_fail "编译工具包 安装"

  if [[ "${cmd}" == "yum" ]]; then
      ${cmd} -y install pcre pcre-devel zlib-devel epel-release
  else
      ${cmd} -y install libpcre3 libpcre3-dev zlib1g-dev dbus
  fi
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}
close_firewall() {
  systemctl stop firewalld.service
  systemctl disable firewalld.service
  echo -e "${Info} firewalld 已关闭 ${Font}"
}
open_port() {
  if [[ ${release} != "centos" ]]; then
    #iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    #iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT
    ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
    ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport 443 -j ACCEPT
    ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
    ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport 443 -j ACCEPT
    iptables-save >/etc/iptables.rules.v4
		ip6tables-save >/etc/iptables.rules.v6
    netfilter-persistent save
    netfilter-persistent reload
  else
    firewall-cmd --zone=public --add-port=80/tcp --permanent
    firewall-cmd --zone=public --add-port=443/tcp --permanent
	fi
}

get_ip() {
  local_ip=$(curl -s https://ipinfo.io/ip)
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s https://api.ip.sb/ip)
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s https://api.ipify.org)
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s https://ip.seeip.org)
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s https://ifconfig.co/ip)
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s https://api.myip.com | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s icanhazip.com)
  [[ -z ${local_ip} ]] && ${local_ip}=$(curl -s myip.ipip.net | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
  [[ -z ${local_ip} ]] && echo -e "${Error}获取不到你vps的ip地址" && exit
}
check_domain() {
  read -rp "请输入您的域名(如果用Cloudflare解析域名，请点击小云彩使其变灰):" domain
  real_ip=$(ping "${domain}" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
  while [ "${real_ip}" != "${local_ip}" ]; do
    read -rp "本机IP和域名绑定的IP不一致，请检查域名是否解析成功,并重新输入域名:" domain
    real_ip=$(ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
    read -rp "我已人工确认，本机Ip和域名绑定的IP一致，继续安装（Y/n）？（默认:n）" continue_install
    [[ -z ${continue_install} ]] && continue_install="n"
    case ${continue_install} in
    [yY][eE][sS] | [yY])
        echo -e "${Tip} 继续安装"
        break
        ;;
    *)
        echo -e "${Tip} 安装终止"
        exit 2
        ;;
    esac
  done
}

uninstall_web() {
  [[ -d ${web_dir} ]] && rm -rf ${web_dir} && echo -e "${Info}开始删除伪装网站……" && echo -e "${Info}伪装网站删除成功！"
}

tls_generate_script_install() {
    if [[ "${cmd}" == "yum" ]]; then
        ${cmd} install socat nc -y
    else
        ${cmd} install socat netcat -y
    fi
    sucess_or_fail "安装 tls 证书生成脚本依赖"

    curl https://get.acme.sh | sh
    sucess_or_fail "安装 tls 证书生成脚本"
    source ~/.bashrc
}
tls_generate() {
  if [[ -f "/data/${domain}/fullchain.crt" ]] && [[ -f "/data/${domain}/privkey.key" ]]; then
    echo -e "${Info}证书已存在……不需要再重新签发了……"
  else
    if "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force --test; then
        echo -e "${Info} TLS 证书测试签发成功，开始正式签发"
        rm -rf "$HOME/.acme.sh/${domain}_ecc"
        sleep 2
    else
        echo -e "${Error}TLS 证书测试签发失败 "
        rm -rf "$HOME/.acme.sh/${domain}_ecc"
        exit 1
    fi

    if "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force; then
        echo -e "${Info} TLS 证书生成成功 "
        sleep 2
        mkdir /data
        mkdir /data/${domain}
        if "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /data/${domain}/fullchain.crt --keypath /data/${domain}/privkey.key --ecc --force; then
            echo -e "${Info}证书配置成功 "
            sleep 2
        fi
    else
        echo -e "${Error} TLS 证书生成失败"
        rm -rf "$HOME/.acme.sh/${domain}_ecc"
        exit 1
    fi
  fi
}
install_nginx() {
  if [[ -f ${nginx_bin_file} ]]; then
     echo -e "${Info} Nginx已存在，跳过编译安装过程 ${Font}"
     sleep 2
  else
    wget -nc --no-check-certificate http://nginx.org/download/nginx-${nginx_version}.tar.gz -P ${nginx_openssl_src}
    sucess_or_fail "Nginx 下载"
    wget -nc --no-check-certificate https://www.openssl.org/source/openssl-${openssl_version}.tar.gz -P ${nginx_openssl_src}
    sucess_or_fail "openssl 下载"
    wget -nc --no-check-certificate https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_version}/jemalloc-${jemalloc_version}.tar.bz2 -P ${nginx_openssl_src}
    sucess_or_fail "jemalloc 下载"
    cd ${nginx_openssl_src} || exit

    [[ -d nginx-"$nginx_version" ]] && rm -rf nginx-"$nginx_version"
    tar -zxvf nginx-"$nginx_version".tar.gz

    [[ -d openssl-"$openssl_version" ]] && rm -rf openssl-"$openssl_version"
    tar -zxvf openssl-"$openssl_version".tar.gz

    [[ -d jemalloc-"${jemalloc_version}" ]] && rm -rf jemalloc-"${jemalloc_version}"
    tar -xvf jemalloc-"${jemalloc_version}".tar.bz2

    [[ -d "$nginx_dir" ]] && rm -rf ${nginx_dir}

    echo -e "${Info} 开始编译并安装 jemalloc……"
    sleep 2

    cd jemalloc-${jemalloc_version} || exit
    ./configure
    sucess_or_fail "编译检查……"
    make && make install
    sucess_or_fail "jemalloc 编译安装"
    echo '/usr/local/lib' >/etc/ld.so.conf.d/local.conf
    ldconfig

    echo -e "${Info} 即将开始编译安装 Nginx, 过程稍久，请耐心等待……"
    sleep 4

    cd ../nginx-${nginx_version} || exit

    ./configure --prefix="${nginx_dir}" \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-pcre \
        --with-http_realip_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_secure_link_module \
        --with-http_v2_module \
        --with-cc-opt='-O3' \
        --with-ld-opt="-ljemalloc" \
        --with-openssl=../openssl-"$openssl_version"
    sucess_or_fail "编译检查"
    make && make install
    sucess_or_fail "Nginx 编译安装"

    # 修改基本配置
    sed -i 's/#user  nobody;/user  root;/' ${nginx_dir}/conf/nginx.conf
    sed -i 's/worker_processes  1;/worker_processes  3;/' ${nginx_dir}/conf/nginx.conf
    sed -i 's/    worker_connections  1024;/    worker_connections  4096;/' ${nginx_dir}/conf/nginx.conf
    sed -i '$i include conf.d/*.conf;' ${nginx_dir}/conf/nginx.conf

    # 删除临时文件
    rm -rf ../nginx-"${nginx_version}"
    rm -rf ../openssl-"${openssl_version}"
    rm -rf ../nginx-"${nginx_version}".tar.gz
    rm -rf ../openssl-"${openssl_version}".tar.gz

    # 添加配置文件夹，适配旧版脚本
    mkdir ${nginx_dir}/conf/conf.d
fi
}
nginx_systemd() {
  touch ${nginx_systemd_file}
  cat >${nginx_systemd_file} <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target
[Service]
Type=forking
PIDFile=/etc/nginx/logs/nginx.pid
ExecStartPre=/etc/nginx/sbin/nginx -t
ExecStart=/etc/nginx/sbin/nginx -c ${nginx_dir}/conf/nginx.conf
ExecReload=/etc/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
  sucess_or_fail "Nginx systemd ServerFile 添加"
  systemctl daemon-reload
}
trojan_go_systemd(){
  touch ${trojan_systemd_file}
  cat >${trojan_systemd_file} << EOF
[Unit]
Description=trojan
Documentation=https://github.com/p4gefau1t/trojan-go
After=network.target

[Service]
Type=simple
StandardError=journal
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/etc/trojan/bin/trojan-go -config /etc/trojan/conf/server.json
ExecReload=
ExecStop=/etc/trojan/bin/trojan-go
LimitNOFILE=51200
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
}
uninstall_nginx() {
  if [[ -f ${nginx_bin_file} ]]; then
        echo -e "${Tip} 是否卸载 Nginx [Y/N]? "
        read -r uninstall_nginx
        case ${uninstall_nginx} in
        [yY][eE][sS] | [yY])
            rm -rf ${nginx_dir}
            echo -e "${Info} 已卸载 Nginx ${Font}"
            ;;
        *) ;;
        esac
    fi
}
download_install(){
  [[ ! -d ${trojan_dir} ]] && mkdir ${trojan_dir}
  [[ ! -d ${trojan_bin_dir} ]] && mkdir ${trojan_bin_dir}
  if [[ ! -f ${trojan_bin_dir}/trojan-go ]];then
      case  ${bit} in
      "x86_64")
        wget --no-check-certificate -O ${trojan_bin_dir}/trojan-go-linux-amd64.zip "https://github.com/p4gefau1t/trojan-go/releases/download/v0.4.10/trojan-go-linux-amd64.zip"
        sucess_or_fail "trojan-go下载"
        unzip -o -d ${trojan_bin_dir} ${trojan_bin_dir}/trojan-go-linux-amd64.zip
        sucess_or_fail "trojan-go解压"
        ;;
      "i386" | "i686")
        wget --no-check-certificate -O ${trojan_bin_dir}/trojan-go-linux-386.zip "https://github.com/p4gefau1t/trojan-go/releases/download/v0.4.10/trojan-go-linux-386.zip"
         sucess_or_fail "trojan-go下载"
        unzip -o -d ${trojan_bin_dir} ${trojan_bin_dir}/trojan-go-linux-386.zip
        sucess_or_fail "trojan-go解压"
        ;;
      "armv7l")
        wget --no-check-certificate -O ${trojan_bin_dir}/trojan-go-linux-armv7.zip "https://github.com/p4gefau1t/trojan-go/releases/download/v0.4.10/trojan-go-linux-armv7.zip"
         sucess_or_fail "trojan-go下载"
        unzip -o -d ${trojan_bin_dir} ${trojan_bin_dir}/trojan-go-linux-armv7.zip
        sucess_or_fail "trojan-go解压"
        ;;
      *)
        echo -e "${Error}不支持 [${bit}] ! 请向Jeannie反馈[]中的名称，会及时添加支持。" && exit 1
        ;;
      esac
      rm -f ${trojan_bin_dir}/trojan-go-linux-amd64.zip
      rm -f ${trojan_bin_dir}/trojan-go-linux-386.zip
      rm -f ${trojan_bin_dir}/trojan-go-linux-armv7.zip
  else
    echo -e "${Info}trojan-go已存在，无需安装"
  fi
}

trojan_go_uninstall(){
  [[ -d ${trojan_dir} ]] && rm -rf ${trojan_dir} && echo -e "${Info}Trojan-go卸载成功"
}
trojan_go_qr_config(){
  touch ${trojan_qr_config_file}
  cat >${trojan_qr_config_file} <<-EOF
  "domain": "${domain}"
  "uuid": "${uuid}"
  "password": "${password}"
  "obfuscation_password":"${obfuscation_password}"
  "websocket_status":"${websocket_status}"
  "double_tls":"${double_tls}"
  "websocket_path":"${websocket_path}"
EOF
}
trojan_info_extraction() {
  grep "$1" ${trojan_conf_file} | awk -F '"' '{print $4}'
}
trojan_go_conf(){
  [[ ! -d ${trojan_conf_dir} ]] && mkdir ${trojan_conf_dir}
  touch ${trojan_conf_file}
  read -rp "$(echo -e "${Info}请输入您的Trojan-go密码:")" password
  while [[ -z ${password} ]]; do
    read -rp "$(echo -e "${Tip}密码不能为空,请重新输入您的Trojan-go密码:")" password
  done
  cat >${trojan_conf_file} <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "log_level": 1,
  "log_file": "",
  "password": [
       "${password}"
  ],
  "buffer_size": 32,
  "dns": [],
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "/data/${domain}/fullchain.crt",
    "key": "/data/${domain}/privkey.key",
    "key_password": "",
    "cipher": "",
    "cipher_tls13": "",
    "curves": "",
    "prefer_server_cipher": false,
    "sni": "",
    "alpn": [
      "http/1.1"
    ],
    "session_ticket": true,
    "reuse_session": true,
    "plain_http_response": "",
    "fallback_port": 1234,
    "fingerprint": "firefox",
    "serve_plain_text": false
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "prefer_ipv4": false,
    "fast_open": false,
    "fast_open_qlen": 20
  },
  "mux": {
    "enabled": false,
    "concurrency": 8,
    "idle_timeout": 60
  },
  "router": {
    "enabled": false,
    "bypass": [],
    "proxy": [],
    "block": [],
    "default_policy": "proxy",
    "domain_strategy": "as_is",
    "geoip": "./geoip.dat",
    "geosite": "./geoip.dat"
  },
  "websocket": {
    "enabled": false,
    "path": "",
    "hostname": "127.0.0.1",
    "obfuscation_password": "",
    "double_tls": false,
    "ssl": {
      "verify": true,
      "verify_hostname": true,
      "cert": "/data/${domain}/fullchain.crt",
      "key": "/data/${domain}/privkey.key",
      "key_password": "",
      "prefer_server_cipher": false,
      "sni": "",
      "session_ticket": true,
      "reuse_session": true,
      "plain_http_response": ""
    }
  },
  "forward_proxy": {
    "enabled": false,
    "proxy_addr": "",
    "proxy_port": 0,
    "username": "",
    "password": ""
  },
  "mysql": {
    "enabled": false,
    "server_addr": "localhost",
    "server_port": 3306,
    "database": "",
    "username": "",
    "password": "",
    "check_rate": 60
  },
  "redis": {
    "enabled": false,
    "server_addr": "localhost",
    "server_port": 6379,
    "password": ""
  },
  "api": {
    "enabled": false,
    "api_addr": "",
    "api_port": 0
  }
}
EOF
}
trojan_client_conf(){
  uuid=$(cat /proc/sys/kernel/random/uuid)
  touch ${web_dir}/${uuid}.json
  cat >${web_dir}/${uuid}.json <<EOF
  {
  "run_type": "client",
  "local_addr": "127.0.0.1",
  "local_port": 1080,
  "remote_addr": "${domain}",
  "remote_port": 443,
  "log_level": 1,
  "log_file": "",
  "password": [
    "${password}"
  ],
  "buffer_size": 32,
  "dns": [],
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "/data/${domain}/fullchain.crt",
    "key": "/data/${domain}/privkey.key",
    "key_password": "",
    "cipher": "",
    "cipher_tls13": "",
    "curves": "",
    "prefer_server_cipher": false,
    "sni": "",
    "alpn": [
      "http/1.1"
    ],
    "session_ticket": true,
    "reuse_session": true,
    "plain_http_response": "",
    "fallback_port": 1234,
    "fingerprint": "firefox",
    "serve_plain_text": false
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "prefer_ipv4": false,
    "fast_open": false,
    "fast_open_qlen": 20
  },
  "mux": {
    "enabled": false,
    "concurrency": 8,
    "idle_timeout": 60
  },
  "router": {
    "enabled": false,
    "bypass": [],
    "proxy": [],
    "block": [],
    "default_policy": "proxy",
    "domain_strategy": "as_is",
    "geoip": "./geoip.dat",
    "geosite": "./geoip.dat"
  },
  "websocket": {
    "enabled": false,
    "path": "",
    "hostname": "127.0.0.1",
    "obfuscation_password": "",
    "double_tls": false,
    "ssl": {
      "verify": true,
      "verify_hostname": true,
      "cert": "/data/${domain}/fullchain.crt",
      "key": "/data/${domain}/privkey.key",
      "key_password": "",
      "prefer_server_cipher": false,
      "sni": "",
      "session_ticket": true,
      "reuse_session": true,
      "plain_http_response": ""
    }
  },
  "forward_proxy": {
    "enabled": false,
    "proxy_addr": "",
    "proxy_port": 0,
    "username": "",
    "password": ""
  },
  "mysql": {
    "enabled": false,
    "server_addr": "localhost",
    "server_port": 3306,
    "database": "",
    "username": "",
    "password": "",
    "check_rate": 60
  },
  "redis": {
    "enabled": false,
    "server_addr": "localhost",
    "server_port": 6379,
    "password": ""
  },
  "api": {
    "enabled": false,
    "api_addr": "",
    "api_port": 0
  }
}
EOF
}
web_download() {
  [[ ! -d "${web_dir}" ]] && mkdir "${web_dir}"
  while [[ ! -f "${web_dir}/web.zip" ]]; do
    echo -e "${Tip}伪装网站未下载或下载失败,请选择下面的任意一个进行下载:
      ${Info}1. https://templated.co/intensify
      ${Info}2. https://templated.co/binary
      ${Info}3. https://templated.co/retrospect
      ${Info}4. https://templated.co/spatial
      ${Info}5. https://templated.co/monochromed
      ${Info}6. https://templated.co/transit
      ${Info}7. https://templated.co/interphase
      ${Info}8. https://templated.co/ion
      ${Info}9. https://templated.co/solarize
      ${Info}10. https://templated.co/phaseshift
      ${Info}11. https://templated.co/horizons
      ${Info}12. https://templated.co/grassygrass
      ${Info}13. https://templated.co/breadth
      ${Info}14. https://templated.co/undeviating
      ${Info}15. https://templated.co/lorikeet"
    read -rp "$(echo -e "${Tip}请输入你要下载的网站的数字:")" aNum
    case $aNum in
    1)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/intensify/download
      ;;
    2)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/binary/download
      ;;
    3)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/retrospect/download
      ;;
    4)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/spatial/download
      ;;
    5)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/monochromed/download
      ;;
    6)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/transit/download
      ;;
    7)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/interphase/download
      ;;
    8)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/ion/download
      ;;
    9)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/solarize/download
      ;;
    10)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/phaseshift/download
      ;;
    11)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/horizons/download
      ;;
    12)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/grassygrass/download
      ;;
    13)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/breadth/download
      ;;
    14)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/undeviating/download
      ;;
    15)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/lorikeet/download
      ;;
    *)
      wget -O ${web_dir}/web.zip --no-check-certificate https://templated.co/intensify/download
      ;;
    esac
  done
  unzip -o -d ${web_dir} ${web_dir}/web.zip
}
open_websocket(){
  echo -e "${Info}是否启用websocket协议?注意：开启这个选项不会改善你的链路速度（甚至有可能下降）"
  echo -e "${Info}如果启用了websocket协议,您就可以开启CDN了，如果用cloudflare解析域名的，搭建完成后可以点亮小云彩了。"
  read -rp "$(echo -e "${Info}是否开启（Y/n）？（默认：n）")" Yn
    case ${Yn} in
    [yY][eE][sS] | [yY])
        sed -i "59c    \"enabled\": true," ${trojan_conf_file}
        sed -i "59c    \"enabled\": true," ${web_dir}/"${uuid}".json
        sed -i "60c    \"path\": \"/trojan\"," ${trojan_conf_file}
        sed -i "60c    \"path\": \"/trojan\"," ${web_dir}/"${uuid}".json
        websocket_path="/trojan"
        websocket_status="开启"
        echo -e "${Info}如果您准备使用的国内CDN,为降低遭到国内无良CDN运营商识别的概率，请输入混淆密码"
        echo -e "${Info}设置了混淆密码对性能有一定影响，请自行斟酌安全性和性能的平衡，默认为空"
        read -rp "$(echo -e "请输入混淆密码：")" obfuscation_password
        sed -i "62c \"obfuscation_password\": \"${obfuscation_password}\"," ${trojan_conf_file}
        sed -i "62c \"obfuscation_password\": \"${obfuscation_password}\"," ${web_dir}/${uuid}.json
        sed -i "63c \"double_tls\": true," ${trojan_conf_file}
        sed -i "63c \"double_tls\": true," ${web_dir}/${uuid}.json
        double_tls="开启"
        ;;
    *)
        websocket_status="关闭"
        double_tls="关闭"
        websocket_path=""
        obfuscation_password=""
        ;;
    esac
}
trojan_go_basic_information() {
  {
echo -e "
${GREEN}=========================Trojan-go+tls 安装成功==============================
${FUCHSIA}=========================   Trojan-go 配置信息  =============================
${GREEN}地址：              ${domain}
${GREEN}端口：              443
${GREEN}密码：              ${password}
${GREEN}websocket状态：     ${websocket_status}
${GREEN}websocket路径：     ${websocket_path}
${GREEN}websocket多重TLS：  ${double_tls}
${GREEN}混淆密码：        ${obfuscation_password}
${FUCHSIA}=========================   客户端配置文件  ===============================
${GREEN}详细信息：https://${domain}/${uuid}.html${NO_COLOR}"
} | tee /etc/motd
}

nginx_trojan_conf() {
  touch ${nginx_conf_dir}/default.conf
  cat >${nginx_conf_dir}/default.conf <<EOF
  server {
    listen 80;
    server_name ${domain};
    root ${web_dir};
}
EOF
}
install_caddy() {
  if [[ -d ${caddy_bin_dir} ]] && [[ -f ${caddy_systemd_file} ]] && [[ -d ${caddy_conf_dir} ]]; then
    read -rp "$(echo -e "${Tip}检测到已经安装了caddy,是否重新安装（Y/n）?(默认：n)")" Yn
    [[ -z ${Yn} ]] && Yn="n"
    case ${Yn} in
    [yY][eE][sS] | [yY])
        echo -e "${Info}开始安装caddy……"
        sleep 2
        curl https://getcaddy.com | bash -s personal hook.service
        ;;
    *)
        ;;
    esac
  else
    echo -e "${Info}开始安装caddy……"
    sleep 2
    curl https://getcaddy.com | bash -s personal hook.service
  fi
}
install_caddy_service(){
  echo -e "${Info}开始安装caddy后台管理服务……"
  rm -f ${caddy_systemd_file}
  #if [[ ${email} == "" ]]; then
  #  read -p "$(echo -e "${Info}请填写您的邮箱：")" email
  #  read -p "$(echo -e "${Info}邮箱输入正确吗（Y/n）？（默认：n）")" Yn
  #  [[ -z ${Yn} ]] && Yn="n"
  #  while [[ ${Yn} != "Y" ]] && [[ ${Yn} != "y" ]]; do
  #      read -p "$(echo -e "${Tip}重新填写您的邮箱：")" email
  #      read -p "$(echo -e "${Info}邮箱输入正确吗（Y/n）？（默认：n）")" Yn
  #      [[ -z ${Yn} ]] && Yn="n"
  #  done
 #fi
 #caddy -service install -agree -email "${email}" -conf "${caddy_conf}"
 caddy -service install -agree -email "example@gmail.com" -conf "${caddy_conf}"
 sucess_or_fail "caddy后台管理服务安装"
}
caddy_trojan_conf() {
   [[ ! -d ${caddy_conf_dir} ]] && mkdir ${caddy_conf_dir}
  touch ${caddy_conf}
  cat >${caddy_conf} <<_EOF
http://${domain}:80 {
  gzip
  timeouts none
  tls /data/${domain}/fullchain.crt /data/${domain}/privkey.key {
       protocols tls1.0 tls1.3
    }
  root ${web_dir}
}
_EOF
}
uninstall_caddy() {
  if [[ -f ${caddy_bin_dir}/caddy ]] || [[ -f ${caddy_systemd_file} ]] || [[ -d ${caddy_conf_dir} ]] || [[ -f ${caddy_bin_dir}/caddy_old ]]; then
    echo -e "${Info}开始卸载Caddy……"
    [[ -f ${caddy_bin_dir}/caddy ]] && rm -f ${caddy_bin_dir}/caddy
    [[ -f ${caddy_bin_dir}/caddy_old ]] && rm -f ${caddy_bin_dir}/caddy_old
    [[ -d ${caddy_conf_dir} ]] && rm -rf ${caddy_conf_dir}
    [[ -f ${caddy_systemd_file} ]] && rm -f ${caddy_systemd_file}
    echo -e "${Info}Caddy卸载成功！"
  fi
}
port_used_check() {
    if [[ 0 -eq $(lsof -i:"$1" | grep -i -c "listen") ]]; then
        echo -e "${Info} $1 端口未被占用"
        sleep 1
    else
        echo -e "${Error}检测到 $1 端口被占用，以下为 $1 端口占用信息 ${Font}"
        lsof -i:"$1"
        echo -e "${Info} 5s 后将尝试自动 kill 占用进程 "
        sleep 5
        lsof -i:"$1" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo -e "${Info} kill 完成"
        sleep 1
    fi
}
install_bbr() {
  wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"
  chmod +x tcp.sh
  ./tcp.sh
}
download_trojan_mgr(){
  curl -s -o /etc/trojan_mgr.sh https://raw.githubusercontent.com/JeannieStudio/all_install/master/trojan_mgr.sh
  sucess_or_fail "修改密码、混淆密码、启用/禁用websocket、查询证书相关信息的管理脚本下载"
  chmod +x /etc/trojan_mgr.sh
}
remove_trojan_mgr(){
  [[ -f /etc/trojan_mgr.sh ]] && rm -f /etc/trojan_mgr.sh && echo -e "${Info}trojan_mgr.sh删除成功"
}
trojan_go_info_html() {
  vps="Trojan-go"
  wget --no-check-certificate -O ${web_dir}/trojan_go_tmpl.html https://raw.githubusercontent.com/JeannieStudio/jeannie/master/trojan_go_tmpl.html
  chmod +x ${web_dir}/trojan_go_tmpl.html
eval "cat <<EOF
  $(<${web_dir}/trojan_go_tmpl.html)
EOF
" >${web_dir}/${uuid}.html
}
trojan_nginx_install(){
  check_root
  check_sys
  sys_cmd
  sucess_or_fail
  #GCE_debian10
  install_dependency
  #close_firewall
  download_install
  port_used_check 80
  port_used_check 443
  uninstall_web
  remove_trojan_mgr
  uninstall_caddy
  get_ip
  check_domain
  tls_generate_script_install
  tls_generate
  web_download
  #generate_trojan_go_tls
  trojan_go_conf
  trojan_client_conf
  open_websocket
  trojan_go_qr_config
  install_nginx
  nginx_systemd
  nginx_trojan_conf
  systemctl restart nginx
  systemctl enable nginx
  trojan_go_info_html
  trojan_go_systemd
  systemctl start trojan.service
	systemctl enable trojan.service
	download_trojan_mgr
  trojan_go_basic_information
}
trojan_caddy_install(){
  check_root
  # shellcheck disable=SC2164
  cd /root
  set_SELINUX
  check_sys
  sys_cmd
  sucess_or_fail
  install_dependency
  #close_firewall
  download_install
  port_used_check 80
  port_used_check 443
  uninstall_web
  remove_trojan_mgr
  uninstall_nginx
  get_ip
  check_domain
  tls_generate_script_install
  tls_generate
  web_download
  #generate_trojan_go_tls
  trojan_go_conf
  trojan_client_conf
  open_websocket
  trojan_go_qr_config
  install_caddy
  install_caddy_service
  caddy_trojan_conf
  caddy -service start
  trojan_go_info_html
  trojan_go_systemd
  systemctl start trojan.service
	systemctl enable trojan.service
	download_trojan_mgr
  trojan_go_basic_information
}
uninstall_all(){
  uninstall_nginx
  trojan_go_uninstall
  uninstall_caddy
  uninstall_web
  remove_trojan_mgr
  echo -e "${Info}卸载完成，系统回到初始状态！"
}
main() {
  echo -e "
${FUCHSIA}===================================================
${GREEN}Trojan-go二合一脚本
${FUCHSIA}===================================================
${GREEN}如果已经安装了下列脚本之一，想要安装其他的，不需要单独执行卸载，直接选择想要安装脚本对应的数字即可……
${GREEN}因为安装的同时会执行卸载，除非想卸载干净回到初始状态,可以执行3……
${FUCHSIA}===================================================
${GREEN}1. 安装trojan-go + nginx +tls
${FUCHSIA}===================================================
${GREEN}2. 安装trojan-go + caddy +tls
${FUCHSIA}===================================================
${GREEN}3. 卸载全部，系统回到初始状态
${FUCHSIA}===================================================
${GREEN}4. 安装BBR加速
${FUCHSIA}===================================================
${GREEN}0. 啥也不做，退出${NO_COLOR}"
  read -rp "请输入数字：" menu_num
  case $menu_num in
  1)
    trojan_nginx_install
    ;;
  2)
    trojan_caddy_install
    ;;
  3)
    uninstall_all
    ;;
  4)
    install_bbr
    ;;
  0)
    exit 0
    ;;
  *)
    echo -e "${RedBG}请输入正确的数字${Font}"
    ;;
  esac
}
main
