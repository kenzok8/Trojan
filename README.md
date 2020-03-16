#### Trojan one key


##### 说明

- 最新脚本会自动获取最新Trojan程序

- vps上需要安装curl  Ubuntu/Debian 系统安装 Curl 方法
```bash
 apt-get update -y && apt-get install curl -y    
```
- Centos 系统安装 Curl 方法
```bash
  yum update -y && yum install curl -y            
```
- 80端口被Nginx点用使用命令 service nginx stop 停用


##### Trojan一键安装脚本二选一:

```bash
curl -O https://git.io/Jvc32 && chmod +x mu.sh && ./mu.sh
```
```bash
bash <(curl -s -L https://git.io/Jvc32)
```
- atrandys脚本修改

```bash
bash <(curl -s -L https://git.io/Jvcyx)
```
![Trojan脚本运行](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-7.png)

 BBR加速(可选):

```bash
cd /usr/src && wget -N --no-check-certificate "https://git.io/Jvc36" && chmod +x tcp.sh && ./tcp.sh
```

```bash
bash <(curl -L -s -k "https://git.io/Jvc36")
```
![BBR脚本运行](https://github.com/kenzok8/Trojan/blob/master/sshot/3.png)


##### 注意

1、系统支持centos7+/debian9+/ubuntu16+

2、域名解析到VPS需要间生效，建议留10分钟,用cloudflare解析，能良好支持TLS；

3、脚本自动续签https证书；

4、自动配置伪装网站，位于/usr/share/nginx/html/目录下，可自行替换其中内容；

5、trojan不能用CDN，不要开启CDN；

6、如果你在用谷歌云需要注意防火墙出入站规则设置并给80和443访问权限。

##### 结尾

- 电脑上其他软件如何使用 Trojan

1、如果软件支持配置 socks5，直接指向 127.0.0.1:1080 即可。

2、如果软件不支持配置 socks5，可选择 sstap/sockscap64/supercap 等软件，曲线实现代理。

3、[mellow github地址](https://github.com/mellow-io/mellow/releases)工具可以实现分流

##### conf配置文件

```bash
[Endpoint]
; tag, parser, parser-specific params...
Direct, builtin, freedom, domainStrategy=UseIP
Reject, builtin, blackhole
Dns-Out, builtin, dns
Http-Out, builtin, http, address=192.168.100.1, port=1087, user=myuser, pass=mypass
Socks-Out, builtin, socks, address=127.0.0.1, port=1080
Proxy-1, vmess1, vmess1://75da2e14-4d08-480b-b3cb-0079a0c51275@example.com:443/path?network=ws&tls=true&ws.host=example.com
Proxy-2, vmess1, vmess1://75da2e14-4d08-480b-b3cb-0079a0c51275@example.com:10025?network=tcp
Proxy-3, ss, ss://aes-128-gcm:pass@192.168.100.1:8888
Proxy-4, vmess1, vmess1://75da2e14-4d08-480b-b3cb-0079a0c51275@example.com:443/path?network=http&http.host=example.com%2Cexample1.com&tls=true&tls.allowinsecure=true
Proxy-7, vmess1, vmess1://75da2e14-4d08-480b-b3cb-0079a0c51275@example.com:10025?network=kcp&kcp.mtu=1350&kcp.tti=20&kcp.uplinkcapacity=1&kcp.downlinkcapacity=2&kcp.congestion=false&header=none&sockopt.tos=184
Proxy-8, vmess1, vmess1://75da2e14-4d08-480b-b3cb-0079a0c51275@example.com:10025?network=quic&quic.security=none&quic.key=&header=none&tls=false&sockopt.tos=184
 
[EndpointGroup]
; tag, colon-seperated list of selectors or endpoint tags, strategy, strategy-specific params...
Group-1, Socks-Out, interval=300, timeout=6
 
[Routing]
domainStrategy = IPIfNonMatch
 
[RoutingRule]
; type, filter, endpoint tag or enpoint group tag
DOMAIN-KEYWORD, geosite:category-ads-all, Reject
IP-CIDR, 223.5.5.5/32, Direct
IP-CIDR, 8.8.8.8/32, Group-1
IP-CIDR, 8.8.4.4/32, Group-1
PROCESS-NAME, trojan.exe, Direct
GEOIP, cn, Direct
GEOIP, private, Direct
PORT, 123, Direct
DOMAIN-KEYWORD, geosite:cn, Direct
DOMAIN, www.google.com, Group-1
DOMAIN-FULL, www.google.com, Group-1
DOMAIN-SUFFIX, google.com, Group-1
FINAL, Group-1
 
[Dns]
; hijack = dns endpoint tag
hijack = Dns-Out
; cliengIp = ip
clientIp = 223.5.5.5
 
[DnsServer]
; address, port, tag
localhost
119.29.29.29
8.8.8.8, 53, Remote
8.8.4.4
 
[DnsRule]
; type, filter, dns server tag
DOMAIN-KEYWORD, geosite:geolocation-!cn, Remote
DOMAIN-SUFFIX, google.com, Remote
 
[DnsHost]
; domain = ip
doubleclick.net = 127.0.0.1
 
[Log]
loglevel = warning
```

- 服务端怎么修改密码

trojan 服务端配置文件路径如下，如需修改内容，修改以下文件即可。

```bash
nano /usr/src/trojan/server.conf (没有nano请调用vi命令)

修改完成后，重启 trojan 服务端即可，同时客户端的密码也要同步修改哦。
systemctl start trojan    #启动 Trojan
systemctl restart trojan  #重启 Trojan
systemctl enable trojan   #设置 Trojan 为开机自启

```
![密码修改](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-5.png)

##### 建议国内域名去cf设置解析
 
 - 地址 https://www.cloudflare.com/

![cf设置截图](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-4.png)


