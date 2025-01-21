# OpenResty 管理脚本使用说明

## 系统要求

- 操作系统：Ubuntu/Debian
- 运行环境：需要 root 权限

## 快速开始

### 一键安装运行

```bash
wget -O nginx.sh https://raw.githubusercontent.com/yourusername/openresty-manager/main/nginx.sh && chmod +x nginx.sh && sudo ./nginx.sh
```

## 功能特点

1. 站点管理
   - 创建新站点
   - 删除站点
   - 查看所有站点

2. 反向代理管理
   - 添加反向代理
   - 删除反向代理
   - 查看所有反向代理

3. SSL证书管理
   - 安装SSL证书
   - 更新SSL证书
   - 删除SSL证书
   - 查看SSL证书

4. 系统维护
   - 启动/停止/重启服务
   - 升级 OpenResty
   - 卸载 OpenResty
   - 备份/还原配置
   - 恢复默认配置

## 使用说明

### 1. 安装说明
- 首次运行脚本会自动检测是否安装OpenResty
- 如未安装，会提供快速安装和完整安装两个选项
- 安装完成后会自动配置并启动服务

### 2. 站点管理
- 创建站点时会自动生成配置文件和目录结构
- 支持自定义域名和端口
- 自动配置站点日志

### 3. 反向代理
- 支持HTTP/HTTPS反向代理
- 自动配置SSL证书（如果已安装）
- 包含错误页面和状态监控

### 4. SSL证书
- 支持从文件读取和手动粘贴两种方式
- 自动检查证书有效性
- 配置失败自动回滚

### 5. 备份还原
- 自动创建配置备份
- 支持选择性还原
- 包含完整的配置信息

## 常见问题解决

### 1. 安装失败
- 检查系统版本是否支持
- 执行 \`dpkg --configure -a\` 修复依赖
- 确保系统源可用

### 2. 启动失败
- 检查错误日志：\`/usr/local/openresty/nginx/logs/error.log\`
- 验证配置文件：\`openresty -t\`
- 检查端口占用：\`netstat -tlnp | grep 80\`

### 3. 证书问题
- 确保证书格式正确（PEM格式）
- 检查证书权限设置
- 验证证书链完整性

### 4. 反向代理500错误
- 检查目标服务是否可访问
- 验证代理配置是否正确
- 查看错误日志定位问题

### 5. 配置还原失败
- 使用恢复默认配置功能
- 从备份中手动恢复关键文件
- 检查文件权限设置

## 目录结构

```
/usr/local/openresty/
├── nginx/
│   ├── conf/
│   │   ├── nginx.conf
│   │   ├── sites-available/
│   │   ├── sites-enabled/
│   │   └── ssl/
│   ├── html/
│   └── logs/
└── backup/
```

## 配置文件说明

### 1. nginx.conf
主配置文件，包含全局设置

### 2. sites-available
存放所有站点配置文件

### 3. sites-enabled
已启用的站点配置软链接

### 4. ssl
存放SSL证书文件

## 日志文件

- 访问日志：\`/usr/local/openresty/nginx/logs/access.log\`
- 错误日志：\`/usr/local/openresty/nginx/logs/error.log\`
- 站点日志：\`/usr/local/openresty/nginx/logs/站点名称_access.log\`

## 安全建议

1. 定期备份配置文件
2. 及时更新系统和OpenResty版本
3. 使用强密码和密钥
4. 定期检查日志文件
5. 限制关键目录访问权限

## 更新记录

### v1.0
- 初始版本发布
- 基础功能实现
- 支持Ubuntu系统
欢迎提交Issue和Pull Request来改进脚本。

## 联系方式

如有问题请提交Issue或发送邮件至：your@email.com 