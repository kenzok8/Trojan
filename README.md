  # Trojan


## 说明

- vps上需要安装curl  Ubuntu/Debian 系统安装 Curl 方法

- apt-get update -y && apt-get install curl -y    

- Centos 系统安装 Curl 方法

- yum update -y && yum install curl -y            

- 80端口被Nginx点用使用命令 service nginx stop 停用


## Trojan一键安装脚本二选一:

```bash
curl -O https://git.io/Jvc32 && chmod +x mu.sh && ./mu.sh
```
```bash
bash <(curl -s -L https://git.io/Jvc32)
```
- atrandys脚本修改

```bash
curl -O https://git.io/JvcME && chmod +x mu.sh && ./mu.sh
```
```bash
bash <(curl -s -L https://git.io/JvcME)
```

 BBR加速(可选):

```bash
cd /usr/src && wget -N --no-check-certificate "https://git.io/Jvc36" && chmod +x tcp.sh && ./tcp.sh
```

## 注意

1、系统支持centos7+/debian9+/ubuntu16+

2、域名解析到VPS需要间生效，建议留10分钟,用cloudflare解析，能良好支持TLS；

3、脚本自动续签https证书；

4、自动配置伪装网站，位于/usr/share/nginx/html/目录下，可自行替换其中内容；

5、trojan不能用CDN，不要开启CDN；

6、如果你在用谷歌云需要注意防火墙出入站规则设置并给80和443访问权限。

## 结尾

- 电脑上其他软件如何使用 Trojan

1、如果软件支持配置 socks5，直接指向 127.0.0.1:1080 即可。

2、如果软件不支持配置 socks5，可选择 sstap/sockscap64/supercap 等软件，曲线实现代理。

- 服务端怎么修改密码

trojan 服务端配置文件路径如下，如需修改内容，修改以下文件即可。

```bash
nano/usr/src/trojan/server.conf (没有nano请调用vi命令)

修改完成后，重启 trojan 服务端即可，同时客户端的密码也要同步修改哦。

systemctl restart trojan
```

## 视图
![Trojan脚本运行](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-1.png)
![BBR脚本运行](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-2.png)
![BBR脚本运行1](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-3.png)
![cf设置截图](https://github.com/kenzok8/Trojan/blob/master/sshot/sshot-4.png)


