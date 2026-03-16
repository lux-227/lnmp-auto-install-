# LNMP 环境一键安装 + WordPress 手动部署

本项目包含两个部分：
1. **LNMP 一键安装脚本**：自动在 Ubuntu 上安装 Nginx、MySQL、PHP 并完成基础配置。
2. **WordPress 手动部署指南**：详细记录在 LNMP 环境下手动安装 WordPress 的全过程，包括常见问题排查。

---

## 功能特点

- 一键安装 Nginx、MySQL、PHP（PHP-FPM）及常用扩展
- 自动配置 Nginx 支持 PHP 解析
- 创建 PHP 测试页面验证环境
- 提供 WordPress 手动部署的完整步骤
- 记录部署中遇到的各种错误及解决方案（Nginx 配置、数据库连接、权限问题等）
- 包含关键配置文件示例

---

## 环境要求

- 操作系统：Ubuntu 20.04 / 22.04
- 权限：具有 sudo 权限的用户
- 网络：能够正常访问外网

---

## 第一部分：LNMP 一键安装脚本

### 使用方法

1. 克隆本仓库到本地：
   ```bash
   git clone git@github.com:你的用户名/lnmp-auto-install.git
   cd lnmp-auto-install
   ```

2. 给脚本添加执行权限：
   ```bash
   chmod +x install.sh
   ```

3. 运行脚本：
   ```bash
   ./install.sh
   ```

4. 等待安装完成，脚本会自动启动 Nginx、MySQL、PHP-FPM，并创建一个 PHP 测试页面。

5. 验证安装：
   访问 `http://你的服务器IP/info.php`，应该看到 PHP 信息页面。

### 脚本做了哪些事？

- 更新软件包索引
- 安装 Nginx，并开放 80 端口（通过 ufw 或直接提示）
- 安装 MySQL 8.0，设置 root 密码（默认 `your_password`，建议安装后修改）
- 安装 PHP 8.1 及常用扩展（如 mysqli、curl、gd 等）
- 配置 Nginx 站点启用 PHP 解析
- 重启相关服务
- 在网站根目录创建 `info.php` 用于测试

### 运行截图

![安装过程截图1](screen/sc1.png)
![安装过程截图2](screen/sc2.png)
![PHP 信息页面](screen/sc3.png)

###  注意事项

- 脚本中 MySQL root 密码默认为 `your_password`，**请安装后立即修改**，或修改脚本中的密码变量。
- 如果系统防火墙（ufw）未启用，脚本会跳过防火墙配置，请手动开放 80 端口：

  ```bash
  sudo ufw allow 80/tcp
  ```
- 生产环境建议修改 PHP 配置文件（`/etc/php/8.1/fpm/php.ini`）中的 `cgi.fix_pathinfo` 等安全选项。

---

## WordPress 手动部署指南

在 LNMP 环境安装完成后，我们手动部署 WordPress 博客。以下步骤基于 LNMP 一键脚本构建的环境，但也适用于任何 LNMP 环境。

### 2.1 创建数据库和用户

登录 MySQL：
```bash
mysql -u root -p
# 输入 MySQL root 密码
```

执行 SQL：

```sql
CREATE DATABASE wordpress;
CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'your_strong_password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 2.2 下载并解压 WordPress

```bash
cd /tmp
wget https://cn.wordpress.org/latest-zh_CN.tar.gz
tar -xzf latest-zh_CN.tar.gz
```

### 2.3 复制文件到网站根目录

网站根目录默认为 `/var/www/html`（可根据 Nginx 配置调整）：
```bash
sudo cp -r wordpress/* /var/www/html/
```

如果目录已有文件，可以先备份：
```bash
sudo mv /var/www/html /var/www/html_backup
sudo mkdir -p /var/www/html
sudo cp -r wordpress/* /var/www/html/
```

### 2.4 设置文件权限

找出 PHP-FPM 运行用户（通常为 `www-data`）：
```bash
ps aux | grep php-fpm | head -n 2
```
假设用户为 `www-data`，执行：

```bash
sudo chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
```

### 2.5 配置 WordPress 连接数据库

```bash
cd /var/www/html
sudo cp wp-config-sample.php wp-config.php
sudo nano wp-config.php
```

修改数据库配置部分：
```php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wpuser' );
define( 'DB_PASSWORD', 'your_strong_password' );
define( 'DB_HOST', 'localhost' );
```

保存退出。

### 2.6 配置 Nginx 伪静态

编辑 Nginx 默认站点配置：
```bash
sudo nano /etc/nginx/sites-enabled/default
```

在 `location / { ... }` 块中，添加或修改为：
```nginx
try_files $uri $uri/ /index.php?$args;
```

**注意**：确保该行只出现一次，避免重复导致 Nginx 报错。

测试配置并重载：
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 2.7 通过浏览器完成 WordPress 安装

访问 `http://你的服务器IP`，按照界面提示：
- 选择语言
- 填写站点标题、管理员用户名、密码、邮箱
- 点击“安装 WordPress”

安装成功后，即可登录后台 `http://你的IP/wp-admin`。

### 最终效果截图

![后台仪表盘](screen/sc4.png)
![个人博客页面查看](screen/sc5.png)

---

## 遇到的问题及解决

在手动部署过程中，我遇到了以下典型问题，并记录了解决方法：

| 问题 | 原因 | 解决 |
|------|------|------|
| Nginx 配置测试失败：`"try_files" directive is duplicate` | 默认配置已有一行 `try_files $uri $uri/ =404;`，手动添加后导致重复 | 删除多余行，只保留 `try_files $uri $uri/ /index.php?$args;` |
| 访问网站显示 403 Forbidden | 索引文件中缺少 `index.php` | 在 Nginx 配置的 `index` 指令中添加 `index.php` |
| 数据库连接错误：`Error establishing a database connection` | `wp-config.php` 中的数据库密码与 MySQL 用户密码不一致 | 更新 `wp-config.php` 中的密码，确保一致 |
| 用户登录 MySQL 提示 `Access denied` | 密码错误或用户不存在 | 用 root 重置密码：`ALTER USER 'wpuser'@'localhost' IDENTIFIED BY '新密码';` |
| PHP 页面空白或 500 | PHP-FPM 未运行或配置错误 | 启动 PHP-FPM：`sudo systemctl start php8.1-fpm`，检查日志 |

---

## 项目结构

```
lnmp-auto-install/
├── README.md                # 项目说明文档（当前文件）
├── install.sh               # LNMP 一键安装脚本
├── screen/                  # LNMP 安装截图
│   ├── sc1.png
│   ├── sc2.png
│   └── sc3.png
├── configs/                 # 关键配置文件示例（脱敏）
│   ├── nginx-default.conf   # Nginx 站点配置（含伪静态）
│   └── wp-config-sample.php # WordPress 配置模板
├── images/                  # WordPress 部署截图
│   ├── wordpress-install.png
│   └── dashboard.png
```

---

## 后续优化方向

- 为 WordPress 配置 HTTPS（使用 Let's Encrypt）
- 优化 Nginx 和 PHP 性能（如启用缓存、调整进程数）
- 编写 WordPress 一键部署脚本，基于手动步骤实现自动化
- 添加更多安全配置（如禁止目录浏览、限制上传文件类型）
```

使用说明
1. 打开 VS Code，新建一个文件（快捷键 `Ctrl+N`）；
2. 将上面的内容全选复制，粘贴到新建文件中；
3. 保存文件为 `README.md`（快捷键 `Ctrl+S`）；
4. 按 `Ctrl+K V` 打开分栏预览，即可看到格式化后的效果；
5. 若需要显示截图/图片，需在同级目录创建 `screen/` 和 `images/` 文件夹，并放入对应图片文件。

总结
1. 这份内容是纯标准 Markdown 语法，无任何非标准格式，可直接在 VS Code 中编辑和预览；
2. 代码块均标注了对应语言（bash/sql/php/nginx），VS Code 预览时会有语法高亮；
3. 路径、截图等占位符（如`你的用户名`、`你的服务器IP`）可根据实际情况替换。