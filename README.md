# New-Suoha（lindanbo1688-ctrl 改装版）

全协议一键梭哈脚本（Sing-box + Argo + Reality / HY2 / TUIC / Snell 等）。

本仓库相对上游做了这些改装：

- **节点短命名** + **按公网 IP 自动识别地区前缀**（如 `TW-VLESS-默认`）
- **交互菜单**：安装 / 恢复开机自启 / 卸载 / 查看节点
- **systemd 开机自启**：重启后 **UUID 不变**（Argo 临时域名可能变，会自动改写订阅）

上游参考：[a6216abcd/newsuoha.sh](https://github.com/a6216abcd/newsuoha.sh)

---

## 一键运行命令

登录 VPS（root），执行：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/lindanbo1688-ctrl/newsuoha.sh/main/suoha.sh)"
```

若未预装 `curl`，用 `wget`：

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/lindanbo1688-ctrl/newsuoha.sh/main/suoha.sh)"
```

也可带参数：

```bash
bash suoha.sh              # 菜单
bash suoha.sh install      # 直接安装（会换新 UUID，并开启开机自启）
bash suoha.sh start        # 仅恢复服务（不换 UUID）
bash suoha.sh uninstall    # 卸载
```

---

## 交互菜单

```text
1) 安装 / 重新梭哈（会换新 UUID，并启用开机自启）
2) 恢复服务 / 启用开机自启（不换 UUID）
3) 卸载
4) 查看当前节点信息
0) 退出
```

---

## 节点命名示例（台湾 IP）

```text
TW-VLESS-默认
TW-VLESS-优选1
TW-VLESS-优选2
TW-Trojan-默认
TW-Trojan-优选1
TW-Trojan-优选2
TW-Reality
TW-Reality-gRPC
TW-AnyTLS
TW-HY2
TW-TUIC
TW-Snell
```

地区码由公网 IP 自动识别（`TW` / `JP` / `HK` / `US` …），失败则为 `UN`。

---

## 开机自启说明

- 选 **1 安装** 完成后会注册 `suoha.service`
- VPS **重启后自动恢复**，无需重装，**UUID 不变**
- Argo Quick Tunnel 临时域名重启后可能变化，开机脚本会自动改写订阅；客户端点「更新订阅」即可
- 检查：`systemctl status suoha --no-pager`

---

## 常用路径

| 路径 | 说明 |
|---|---|
| `/opt/suoha_quick/` | 运行目录、配置、证书 |
| `/opt/suoha_quick/v2ray.txt` | 节点与订阅说明 |
| `/var/www/suoha_sub/` | 静态订阅文件 |
| `/etc/suoha_sub_port` | 固定订阅端口 |

查看节点：

```bash
cat /opt/suoha_quick/v2ray.txt
```

---

## 免责声明

仅供个人学习与网络维护测试，请遵守当地法律法规与服务商条款。
