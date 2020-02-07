# Trojan


- 注意

- vps上需要安装curl

- Ubuntu/Debian 系统安装 Curl 方法

- apt-get update -y && apt-get install curl -y    

- Centos 系统安装 Curl 方法

- yum update -y && yum install curl -y            

- 80端口被Nginx点用使用命令 service nginx stop 停用


*Trojan一键安装脚本:

- curl -O https://raw.githubusercontent.com/kenzok8/Trojan/master/mu.sh && chmod +x mu.sh && ./mu.sh


*BBR加速（可选）：

- cd /usr/src && wget -N --no-check-certificate "https://raw.githubusercontent.com/kenzok8/Trojan/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
