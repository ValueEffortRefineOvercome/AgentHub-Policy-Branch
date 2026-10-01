#!/usr/bin/env bash
# PreToolUse hook — main 직접 커밋·push 차단. exit 2 가 도구 호출을 막고
# stderr 가 에이전트에게 전달된다. SKILL.md 6절을 선언에서 강제로 바꾸는 유일한 수단.
#
# 설치 — 소비 프로젝트의 .claude/settings.json:
#   { "hooks": { "PreToolUse": [{ "matcher": "Bash", "hooks": [{
#       "type": "command",
#       "if": "Bash(git *)",
#       "command": "bash .claude/skills/branch-policy/hooks/block-main-push.sh"
#   }]}]}}
# `if` 가 git 명령일 때만 hook 을 띄운다 — 나머지 Bash 호출엔 비용 0.
#
# 정책 저장소(AgentHub, AgentHub-Policy-*) 에는 설치하지 않는다 — 6절 예외 대상.

payload=$(cat)

# ponytail: jq 가 없어 stdin 전체를 grep 한다. 세 가지로 틀릴 수 있다 —
#   (1) 명령이 git 과 push/commit 를 문자열로 품고만 있어도 매칭
#   (2) main 에 있으면서 다른 브랜치를 push 해도 매칭 (git push origin feat/x)
#   (3) main 에 커밋을 만드는 다른 경로는 안 잡는다 (cherry-pick, merge)
# (1)(2) 는 fail-closed(막는 쪽)라 안전하고 브랜치를 만들면 풀린다.
# (3) 이 실제로 발생하면 패턴에 추가한다. jq 가 깔리면 `jq -r '.tool_input.command'`.
grep -Eq 'git\b.*\b(push|commit)\b' <<<"$payload" || exit 0

# 통과시켜야 하는 세 경우를 명시한다 — 예전엔 rev-parse 실패에 의존해 우연히 통과했다.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0   # git 저장소 아님
git rev-parse HEAD      >/dev/null 2>&1 || exit 0   # 커밋 0개 = 초기 커밋, 막으면 부트스트랩 불가
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || exit 0                          # detached HEAD — main 을 건드리지 않는다

case "$branch" in main|master) ;; *) exit 0 ;; esac

cat >&2 <<MSG
branch-policy 위반: $branch 에서 직접 커밋·push 는 금지다.

  git switch -c <type>/<슬러그>     # type: feat|fix|docs|chore

작업 브랜치를 만든 뒤 다시 시도하라. (/branch-policy 2·6절)
MSG
exit 2
