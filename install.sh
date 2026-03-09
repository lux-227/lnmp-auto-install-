#!/bin/bash
#lnmp一键安装脚本
 
 #检查是否以root运行
 if [ "$EUID" -eq 0 ]; then 
    echo "sudo普通用户"
    exit 1
fi


echo "开始装lnmp"

echo "装nginx"
sudo apt update
sudo apt install -y nginx

sudo systemctl start nginx
sudo systemctl enable nginx
if command -v ufw &> /dev/null; then
    sudo ufw allow 80/tcp
    sudo ufw reload
fi 

#检查nginx是否运行
if systemctl is-active --quiet nginx; then
    echo "nginx安装成功"
else 
    echo "nginx启动失败.检查日志"
    exit 1
fi


# 2 安装mysql
echo "安装 MySQL"
MYSQL_PASSWORD="ljy141325"   

echo "mysql-server mysql-server/root_password password $MYSQL_PASSWORD" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_PASSWORD" | sudo debconf-set-selections
sudo apt install -y mysql-server

sudo systemctl start mysql
sudo systemctl enable mysql

# 执行安全配置（删除匿名用户、禁止远程 root 等）
echo "执行 MySQL 安全配置"
mysql -u root -p"$MYSQL_PASSWORD" <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "MySQL 安装配置成功"
else
    echo "MySQL 配置失败，请检查密码或手动执行"
    exit 1
fi


# 3 安装php

echo " 安装 PHP 及常用扩展"
sudo apt install -y php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-zip

# 查找 PHP-FPM 服务名
PHP_FPM_SERVICE=$(systemctl list-units --type=service | grep php | grep fpm | awk '{print $1}' | head -n1)
if [ -z "$PHP_FPM_SERVICE" ]; then
    echo "找不到 PHP-FPM 服务，安装可能失败"
    exit 1
fi

echo "找到 PHP-FPM 服务: $PHP_FPM_SERVICE"
sudo systemctl start $PHP_FPM_SERVICE
sudo systemctl enable $PHP_FPM_SERVICE

if systemctl is-active --quiet $PHP_FPM_SERVICE; then
    echo "PHP-FPM 启动成功"
else
    echo "PHP-FPM 启动失败"
    exit 1
fi





# 4 配置 Nginx 支持 PHP 
echo "配置 Nginx 支持 PHP..."
NGINX_DEFAULT_CONF="/etc/nginx/sites-available/default"
sudo cp $NGINX_DEFAULT_CONF $NGINX_DEFAULT_CONF.bak

# 在 default 文件中添加 PHP 处理配置
sudo sed -i '/index index.html index.htm index.nginx-debian.html;/a \\n\tlocation ~ \\.php$ {\n\t\tinclude snippets/fastcgi-php.conf;\n\t\tfastcgi_pass unix:/var/run/php/php7.4-fpm.sock;\n\t}' $NGINX_DEFAULT_CONF

# 动态获取 sock 路径并替换（适配不同 PHP 版本）
PHP_SOCK=$(find /var/run/php -name "php*-fpm.sock" | head -n1)
if [ -n "$PHP_SOCK" ]; then
    sudo sed -i "s|unix:/var/run/php/php7.4-fpm.sock|unix:$PHP_SOCK|" $NGINX_DEFAULT_CONF
fi

# 测试 Nginx 配置
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx 配置测试失败，请检查配置文件"
    exit 1
fi

sudo systemctl reload nginx
echo "Nginx 配置完成"




# 创建测试
echo "[5/5] 创建 PHP 测试页面..."
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

if curl -s http://localhost/info.php | grep -q "PHP Version"; then
    echo "LNMP 环境部署成功！请在浏览器中打开 http://192.168.211.169/info.php 查看 PHP 信息"
else
    echo "PHP 测试页面访问失败，请检查 Nginx 和 PHP-FPM 配置"
    exit 1
fi

echo "lnmp全部安装完成"