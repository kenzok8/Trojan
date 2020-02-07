# Trojan


- 注意

- vps上需要安装curl

- Ubuntu/Debian 系统安装 Curl 方法

- apt-get update -y && apt-get install curl -y    

- Centos 系统安装 Curl 方法

- yum update -y && yum install curl -y            

- 80端口被Nginx点用使用命令 service nginx stop 停用


 Trojan一键安装脚本二选一:

- curl -O https://raw.githubusercontent.com/kenzok8/Trojan/master/mu.sh && chmod +x mu.sh && ./mu.sh


- bash <(curl -s -L https://raw.githubusercontent.com/kenzok8/Trojan/master/mu.sh)


 BBR加速(可选):

- cd /usr/src && wget -N --no-check-certificate "https://raw.githubusercontent.com/kenzok8/Trojan/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh

- 其余注意事项如下：

1、系统支持centos7+/debian9+/ubuntu16+

2、域名需要解析到VPS需要时间生效，建议留10分钟；

3、脚本自动续签https证书；

4、自动配置伪装网站，位于/usr/share/nginx/html/目录下，可自行替换其中内容；

5、trojan不能用CDN，不要开启CDN；

6、如果你在用谷歌云需要注意防火墙出入站规则设置并给80和443访问权限。
