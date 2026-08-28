#!/usr/bin/env bash
# dispatch.sh —— Herdr worktree 多代理任务派发模板
# 用法:
#   ./dispatch.sh <branch> <prompt> [agent-cmd]     # 建 worktree + 启动 agent
#   ./dispatch.sh --wait   <branch>                  # 等 agent done + 读输出
#   ./dispatch.sh --clean  <branch>                  # 删 worktree + 删分支 + prune
#
# 依赖: herdr, jq, git; 需在仓库根目录运行。

set -euo pipefail

REPO_DIR="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || { echo "not a git repo"; exit 1; })"
TIMEOUT="${HERDR_AGENT_TIMEOUT:-1800000}"

slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | cut -c1-31; }

usage() { sed -n '2,8p' "$0"; exit 1; }

cmd="${1:?}"; shift || usage
case "$cmd" in
  --wait)   MODE="wait";   BRANCH="${1:?branch required}";;
  --clean)  MODE="clean";  BRANCH="${1:?branch required}";;
  -h|--help) usage;;
  *)        MODE="dispatch"; BRANCH="$cmd"; PROMPT="${1:?prompt required}"; AGENT="${2:-claude}";;
esac

LABEL="$(slug "$BRANCH")"

# ---------- 辅助：拿 workspace / pane id ----------
ws_of_branch() {
  herdr worktree list --cwd "$REPO_DIR" --json 2>/dev/null \
    | jq -r ".result.worktrees[] | select(.branch == \"$BRANCH\") | .open_workspace_id // empty" \
    | head -n1
}

# ---------- dispatch ----------
if [ "$MODE" = "dispatch" ]; then
  OUT=$(herdr worktree create --cwd "$REPO_DIR" \
        --branch "$BRANCH" --label "$LABEL" --no-focus --json)
  WS=$(printf '%s' "$OUT" | jq -r '.result.worktree.open_workspace_id // .result.workspace.workspace_id')
  PANE=$(printf '%s' "$OUT" | jq -r '.result.root_pane.pane_id')
  PATH_=$(printf '%s' "$OUT" | jq -r '.result.worktree.path // empty')

  echo "worktree: $PATH_"
  echo "workspace: $WS   pane: $PANE"

  # 等 pane shell 就绪
  sleep 3

  herdr agent start "$AGENT" --kind "$AGENT" --pane "$PANE" --timeout 120000 || {
    # agent 可能以 blocked 状态启动，发 Enter 解除
    herdr agent send-keys "$PANE" Enter
    sleep 2
  }
  herdr agent prompt "$PANE" "$PROMPT"
  herdr agent wait "$PANE" --until idle --timeout "$TIMEOUT" || true

  # 持久化映射，供 --wait / --clean 使用
  mkdir -p .herdr
  printf '{"branch":"%s","workspace":"%s","pane":"%s","path":"%s"}\n' \
    "$BRANCH" "$WS" "$PANE" "$PATH_" >> .herdr/tasks.jsonl

  echo "$WS" >  .herdr/"$LABEL".ws
  echo "$PANE" > .herdr/"$LABEL".pane
  echo "dispatched. 等待用:  $0 --wait $BRANCH"
  exit 0
fi

# ---------- wait ----------
if [ "$MODE" = "wait" ]; then
  PANE="$(cat .herdr/"$LABEL".pane 2>/dev/null || true)"
  [ -z "$PANE" ] && { echo "no pane recorded for $BRANCH"; exit 1; }
  herdr agent wait "$PANE" --until done --timeout "$TIMEOUT" || true
  herdr agent read "$PANE" --source recent --lines 80
  exit 0
fi

# ---------- clean ----------
if [ "$MODE" = "clean" ]; then
  WS="$(cat .herdr/"$LABEL".ws 2>/dev/null || true)"
  if [ -n "$WS" ]; then
    herdr worktree remove --workspace "$WS" 2>/dev/null || true
  fi
  # 若 workspace 记录丢失，按分支反查 worktree 路径兜底
  WT_PATH="$(git -C "$REPO_DIR" worktree list --porcelain \
             | awk -v b="$BRANCH" '/^worktree /{p=$2} /^branch /&&index($0,b){print p; exit}')"
  if [ -n "$WT_PATH" ] && [ "$WT_PATH" != "$REPO_DIR" ]; then
    git -C "$REPO_DIR" worktree remove "$WT_PATH" 2>/dev/null || true
  fi
  git -C "$REPO_DIR" worktree prune 2>/dev/null || true
  # 只在已合并时删本地+远程分支
  if git -C "$REPO_DIR" branch --merged main 2>/dev/null | grep -q "$BRANCH"; then
    git -C "$REPO_DIR" branch -d "$BRANCH" 2>/dev/null || true
    git -C "$REPO_DIR" push origin --delete "$BRANCH" 2>/dev/null || true
  else
    echo "分支 $BRANCH 尚未合并到 main，保留本地分支（仅删 worktree）"
  fi
  rm -f .herdr/"$LABEL".ws .herdr/"$LABEL".pane
  exit 0
fi
