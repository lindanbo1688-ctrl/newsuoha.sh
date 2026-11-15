# 开机自启说明

## 行为

- 安装完成后注册 `suoha.service`
- VPS 重启后自动执行 `/opt/suoha_quick/boot_start.sh`
- **不重新生成 UUID**（沿用 `singbox.json` + `/var/lib/suoha/credentials.env`）
- Argo Quick Tunnel 临时域名重启后可能变化 → `regen_nodes.sh` 按凭据重写订阅

## 菜单

1. 安装 / 重新梭哈（**默认保留旧 UUID**；`install --force` 才换新）
2. 恢复服务 / 启用开机自启（不换 UUID）
3. 卸载
4. 查看节点

已安装时菜单**默认选 2**，避免误重装换号。

## 命令

```bash
bash suoha.sh start            # 手动恢复
bash suoha.sh install          # 重装但保留 UUID
bash suoha.sh install --force  # 强制换新 UUID
systemctl status suoha
systemctl restart suoha
```

## 注意

- 旧机器：用本版再跑一次 `install`（选保留 UUID）以写入凭据文件 + 自启
- 重启后节点连不上：先 **更新订阅**（域名变了），不要重装
