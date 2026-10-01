#!/usr/bin/env bash
# PreToolUse hook — 소비 프로젝트에서 정책 서브모듈 파일 수정을 차단한다.
# exit 2 가 도구 호출을 막고 stderr 가 에이전트에게 전달된다.
#
# 설치 — 소비 프로젝트의 .claude/settings.json:
#   { "hooks": { "PreToolUse": [{ "matcher": "Edit|Write", "hooks": [{
#       "type": "command",
#       "command": "bash .claude/skills/branch-policy/hooks/block-policy-edit.sh"
#   }]}]}}
#
# **정책 허브(AgentHub)에는 설치하지 않는다.** 거기서는 정책 수정이 작업 자체다.
# 설치 위치가 유일한 구분자다 — 경로 모양은 허브와 소비 프로젝트가 같다.
#
# 한계: Bash 로 쓰는 경로(`sed -i`, `cat >`)는 못 막는다. 그건 CI 의 서브모듈 변조
# 탐지가 잡는다 — 머지가 막히므로 main 에는 들어가지 못한다.
set -u
payload=$(cat)

# file_path 추출 (jq 없이). Windows 역슬래시를 / 로 정규화한다.
p=$(printf '%s' "$payload" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$p" ] || exit 0
p=$(printf '%s' "$p" | sed 's|\\|/|g; s|//*|/|g')

[ -f .gitmodules ] || exit 0
# 서브모듈 경로에 공백이 없다는 전제다 — 정책 경로는 .claude/skills/<이름> 뿐이다
subs=$(git config -f .gitmodules --get-regexp '\.path$' 2>/dev/null | awk '{print $2}')
hit=''
for sub in $subs; do
  case "$p" in *"$sub"/*) hit="$sub"; break ;; esac
done
[ -n "$hit" ] || exit 0

cat >&2 <<MSG
정책 서브모듈 파일은 소비 프로젝트에서 수정하지 않는다: $hit

고치는 순서 (/branch-policy 2절 '서브모듈'):
  1. 그 정책 저장소에서 고치고 PR 로 머지한다 — 이 저장소가 아니다
  2. 여기서는 핀만 올린다:  git submodule update --remote $hit

정책 본문은 이 저장소가 소유하지 않는다. 여기서 고치면 어느 저장소에도
커밋되지 않고, 다음 핀 갱신에 덮여 사라진다.
MSG
exit 2
