#!/bin/bash
# tsproxy 一键安装 —— 在一台新的 macOS 上复刻 Tailscale exit-node 代理 + 自动回退看门狗。
# 幂等:可重复运行。用法:
#   bash install.sh                         # 用默认出口设备
#   NODE=某台设备名 INTERVAL=120 bash install.sh
#
# 前置条件:已装 Tailscale 且已登录(command -v tailscale 可用),出口设备已在后台被批准为 exit node。
set -euo pipefail

NODE="${NODE:-xin-han-thinkstation-p520}"      # 出口设备名(MagicDNS 名)
INTERVAL="${INTERVAL:-120}"                     # 看门狗巡检间隔(秒)
DIR="$HOME/.config/tsproxy"
PLIST="$HOME/Library/LaunchAgents/com.user.tsproxy.watchdog.plist"
TS="$(command -v tailscale || echo /usr/local/bin/tailscale)"
LABEL="com.user.tsproxy.watchdog"

command -v tailscale >/dev/null || { echo "❌ 未找到 tailscale,请先安装并登录。"; exit 1; }
mkdir -p "$DIR" "$HOME/Library/LaunchAgents"

# ---- 1. watchdog.sh ----
cat > "$DIR/watchdog.sh" <<WD
#!/bin/bash
# 自动生成 by install.sh —— Tailscale exit-node 看门狗。
NODE="$NODE"
FLAG="\$HOME/.config/tsproxy/enabled"
PAUSED="\$HOME/.config/tsproxy/auto_paused"
TS="$TS"
PY="/usr/bin/python3"

[ -f "\$FLAG" ] || exit 0

read -r NODE_ONLINE EXIT_CONFIGURED EXIT_ONLINE <<EOF
\$(\$TS status --json 2>/dev/null | "\$PY" -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print('x x x'); sys.exit()
node_online='0'
for p in d.get('Peer',{}).values():
    if '\$NODE' in p.get('DNSName',''):
        node_online='1' if p.get('Online') else '0'
        break
es=d.get('ExitNodeStatus')
print(node_online, '1' if es else '0', '1' if (es and es.get('Online')) else '0')
")
EOF

[ "\$NODE_ONLINE" = "x" ] && exit 0

notify() { /usr/bin/osascript -e "display notification \\"\$2\\" with title \\"\$1\\"" >/dev/null 2>&1; }

if [ "\$EXIT_CONFIGURED" = "1" ]; then
    if [ "\$EXIT_ONLINE" = "1" ]; then
        rm -f "\$PAUSED"
    else
        "\$TS" set --exit-node= && touch "\$PAUSED" \\
            && logger -t tsproxy "exit node offline -> fallback to direct" \\
            && notify "Tailscale 代理" "⛔️ \$NODE 掉线,已自动切回直连"
    fi
else
    if [ -f "\$PAUSED" ]; then
        if [ "\$NODE_ONLINE" = "1" ]; then
            "\$TS" set --exit-node="\$NODE" --exit-node-allow-lan-access && rm -f "\$PAUSED" \\
                && logger -t tsproxy "exit node back online -> re-enable proxy" \\
                && notify "Tailscale 代理" "✅ \$NODE 已恢复,代理重新开启"
        fi
    else
        rm -f "\$FLAG" \\
            && logger -t tsproxy "manual disable detected -> stop managing" \\
            && notify "Tailscale 代理" "🖐 检测到手动关闭,看门狗已停止托管"
    fi
fi
WD
chmod +x "$DIR/watchdog.sh"

# ---- 2. launchd plist ----
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>/bin/bash</string><string>$DIR/watchdog.sh</string></array>
    <key>StartInterval</key><integer>$INTERVAL</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardErrorPath</key><string>$DIR/watchdog.err.log</string>
</dict>
</plist>
PL

# ---- 3. 装 tsproxy() 到 ~/.zshrc(幂等:先删旧块再追加) ----
ZRC="$HOME/.zshrc"; touch "$ZRC"
/usr/bin/sed -i '' '/# ---- Tailscale exit-node 代理一键开关 ----/,/^}$/d' "$ZRC" 2>/dev/null || true
cat >> "$ZRC" <<ZF

# ---- Tailscale exit-node 代理一键开关 ----
# 用法: tsproxy on | off | status | toggle
tsproxy() {
  local NODE="$NODE"
  local FLAG="\$HOME/.config/tsproxy/enabled"
  local PAUSED="\$HOME/.config/tsproxy/auto_paused"
  local cur
  cur=\$(tailscale status 2>/dev/null | grep 'exit node' | grep -c "\$NODE")
  case "\${1:-toggle}" in
    on)     mkdir -p "\$HOME/.config/tsproxy"
            tailscale set --exit-node="\$NODE" --exit-node-allow-lan-access \\
              && { rm -f "\$PAUSED"; touch "\$FLAG"; echo "✅ 代理已开启 → \$NODE(看门狗托管中)"; } ;;
    off)    rm -f "\$FLAG" "\$PAUSED"
            tailscale set --exit-node= && echo "⛔️ 代理已关闭(恢复直连,看门狗不再自动重连)" ;;
    status) if [ "\$cur" -ge 1 ]; then echo "🟢 代理开启中 → \$NODE";
            elif [ -f "\$PAUSED" ]; then echo "🟡 出口离线,已回退直连(恢复后自动重连)";
            elif [ -f "\$FLAG" ]; then echo "🟢 托管中(等待生效)";
            else echo "⚪️ 代理未开启(直连)"; fi ;;
    check)  echo "── tsproxy 状态检查 ──"
            tsproxy status
            echo -n "链路: "; tailscale ping --c 1 "\$NODE" 2>/dev/null | tail -1
            echo "对外公网 IP: \$(curl -s --max-time 6 https://ifconfig.me)" ;;
    toggle) if [ -f "\$FLAG" ]; then tsproxy off; else tsproxy on; fi ;;
    *)      echo "用法: tsproxy [on|off|status|check|toggle]" ;;
  esac
}
ZF

# ---- 4. 加载 launchd(幂等) ----
UID_NUM=$(id -u)
launchctl bootout   "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

echo "✅ 安装完成。出口=$NODE  间隔=${INTERVAL}s"
echo "   新终端可用 tsproxy;当前窗口执行:source ~/.zshrc"
echo "   开启代理:tsproxy on"
