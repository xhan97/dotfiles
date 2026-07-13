#!/bin/bash
# Tailscale exit-node 看门狗:
#   thinkstation 在线 -> 确保代理开启;掉线 -> 自动切回直连;恢复 -> 自动切回代理。
# 仅当存在 ~/.config/tsproxy/enabled 标记(即用户希望使用代理)时才动作。
NODE="xin-han-thinkstation-p520"
FLAG="$HOME/.config/tsproxy/enabled"       # 用户意图:希望使用代理(受看门狗托管)
PAUSED="$HOME/.config/tsproxy/auto_paused" # 看门狗因出口掉线而临时暂停的标记
TS="/usr/local/bin/tailscale"
PY="/usr/bin/python3"

[ -f "$FLAG" ] || exit 0   # 用户已手动 tsproxy off,不托管

read -r NODE_ONLINE EXIT_CONFIGURED EXIT_ONLINE <<EOF
$($TS status --json 2>/dev/null | "$PY" -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print('x x x'); sys.exit()
node_online='0'
for p in d.get('Peer',{}).values():
    if '$NODE' in p.get('DNSName',''):
        node_online='1' if p.get('Online') else '0'
        break
es=d.get('ExitNodeStatus')
exit_configured='1' if es else '0'
exit_online='1' if (es and es.get('Online')) else '0'
print(node_online, exit_configured, exit_online)
")
EOF

# 解析失败(tailscale 未就绪等),本次跳过
[ "$NODE_ONLINE" = "x" ] && exit 0

notify() { /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1; }

if [ "$EXIT_CONFIGURED" = "1" ]; then
    if [ "$EXIT_ONLINE" = "1" ]; then
        rm -f "$PAUSED"                      # 一切正常,清掉暂停标记
    else
        # 出口掉线 -> 回退直连,并标记"是看门狗暂停的"(恢复后才自动重连)
        "$TS" set --exit-node= && touch "$PAUSED" \
            && logger -t tsproxy "exit node offline -> fallback to direct" \
            && notify "Tailscale 代理" "⛔️ $NODE 掉线,已自动切回直连"
    fi
else
    # 当前没走代理
    if [ -f "$PAUSED" ]; then
        # 是看门狗因掉线暂停的:出口一旦恢复在线就自动重连
        if [ "$NODE_ONLINE" = "1" ]; then
            "$TS" set --exit-node="$NODE" --exit-node-allow-lan-access && rm -f "$PAUSED" \
                && logger -t tsproxy "exit node back online -> re-enable proxy" \
                && notify "Tailscale 代理" "✅ $NODE 已恢复,代理重新开启"
        fi
        # 出口还没回来 -> 继续等,不打扰
    else
        # 不是看门狗暂停的,却没在走代理 => 你在 Tailscale 里手动关掉了
        # 尊重你的操作:交还控制,不再自动开启(需要时用 tsproxy on 重新托管)
        rm -f "$FLAG" \
            && logger -t tsproxy "manual disable detected -> stop managing" \
            && notify "Tailscale 代理" "🖐 检测到手动关闭,看门狗已停止托管"
    fi
fi
