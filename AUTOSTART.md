# 开机自启说明

## 行为

- 安装完成后注册 `suoha.service`
- VPS 重启后自动执行 `/opt/suoha_quick/boot_start.sh`
- **不重新生成 UUID**（沿用 `singbox.json` / 原节点配置）
- Argo Quick Tunnel 临时域名重启后可能变化 → 脚本自动改写订阅文件

## 菜单

1. 安装 / 重新梭哈（会换新 UUID）
2. 恢复服务 / 启用开机自启（不换 UUID）
3. 卸载
4. 查看节点

## 命令

```bash
bash suoha.sh start       # 手动恢复
systemctl status suoha
systemctl restart suoha
```

## 注意

已在旧版跑过安装的机器：需用本修改版**再安装一次**才会写入自启；之后重启就不用重装了。
