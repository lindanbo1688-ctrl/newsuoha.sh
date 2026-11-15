# New-Suoha（lindanbo1688-ctrl 改装版）

全协议梭哈脚本改装版：**只保留 Argo 默认 + 优选（共 6 个节点）**。

- 节点：`TW-VLESS-默认/优选1/优选2` + `TW-Trojan-默认/优选1/优选2`
- **已移除**：Reality / AnyTLS / HY2 / TUIC / Snell / SS 直连节点
- **按公网 IP 自动识别地区前缀**（TW/JP/HK…）
- **systemd 开机自启**（重启后 UUID/端口不变；凭据持久化到 `/var/lib/suoha`）
- **重装默认保留旧 UUID**（只有 `install --force` 才换新号）

上游参考：[a6216abcd/newsuoha.sh](https://github.com/a6216abcd/newsuoha.sh)

---

## 一键运行命令

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/lindanbo1688-ctrl/newsuoha.sh/main/suoha.sh)"
```

无 curl 时：

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/lindanbo1688-ctrl/newsuoha.sh/main/suoha.sh)"
```

```bash
bash suoha.sh              # 菜单（已安装时默认「恢复」）
bash suoha.sh install      # 安装/重装（默认保留旧 UUID）
bash suoha.sh install --force  # 强制换新 UUID/端口
bash suoha.sh start        # 仅恢复（不换 UUID）
bash suoha.sh uninstall    # 卸载
```

---

## 交互菜单

```text
1) 安装 / 重新梭哈（默认保留旧 UUID；--force 才换新）
2) 恢复服务 / 启用开机自启（不换 UUID）
3) 卸载
4) 查看当前节点信息
0) 退出
```

---

## 只会生成这 6 个节点（台湾示例）

```text
TW-VLESS-默认
TW-VLESS-优选1
TW-VLESS-优选2
TW-Trojan-默认
TW-Trojan-优选1
TW-Trojan-优选2
```

全部走 Cloudflare **443**，不再生成本机 `61.x.x.x:高位端口` 的直连节点。

---

## 开机自启

安装后注册 `suoha.service`。重启自动恢复。

| 项 | 重启后 |
|---|---|
| UUID / WS 路径 / 本机分流端口 | **不变**（`/var/lib/suoha/credentials.env`） |
| Argo 临时域名 `*.trycloudflare.com` | **可能变**（开机脚本自动改写订阅） |

客户端请用**在线订阅**；重启后点「更新订阅」。不要每次重启后再跑一遍「安装」。

```bash
systemctl status suoha --no-pager
cat /var/lib/suoha/credentials.env   # 查看持久化 UUID/端口
```

---

## 免责声明

仅供个人学习与网络维护测试，请遵守当地法律法规与服务商条款。
