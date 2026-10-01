#!/usr/bin/env bash
# hooks/block-policy-edit.sh 자체 검사. 픽스처 저장소에서 경로 판정만 본다.
H="$(cd "$(dirname "$0")/../hooks" && pwd)/block-policy-edit.sh"
fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
cat > .gitmodules <<'EOF'
[submodule ".claude/skills/branch-policy"]
	path = .claude/skills/branch-policy
	url = https://example.invalid/x.git
[submodule ".claude/skills/task-policy"]
	path = .claude/skills/task-policy
	url = https://example.invalid/y.git
EOF

t(){ # t <기대exit> <설명> <JSON>
  printf '  %-46s ' "$2"
  printf '%s' "$3" | bash "$H" >/dev/null 2>&1
  c=$?
  if [ "$c" = "$1" ]; then echo OK; else echo "FAIL (exit $c, 기대 $1)"; fail=1; fi
}

t 2 "정책 파일 Edit (상대경로)" \
  '{"tool_name":"Edit","tool_input":{"file_path":".claude/skills/branch-policy/SKILL.md"}}'
t 2 "정책 파일 Write" \
  '{"tool_name":"Write","tool_input":{"file_path":".claude/skills/task-policy/SKILL.md"}}'
t 2 "정책 하위 디렉토리 파일" \
  '{"tool_name":"Edit","tool_input":{"file_path":".claude/skills/task-policy/references/pipeline.md"}}'
t 2 "Windows 절대경로 역슬래시" \
  '{"tool_name":"Edit","tool_input":{"file_path":"C:\dev\p\.claude\skills\branch-policy\SKILL.md"}}'
t 0 "프로젝트 고유 skill 은 허용" \
  '{"tool_name":"Edit","tool_input":{"file_path":".claude/skills/project-notes/SKILL.md"}}'
t 0 "프로젝트 코드는 허용" \
  '{"tool_name":"Write","tool_input":{"file_path":"taskforge/cli.py"}}'
t 0 "settings.json 은 허용 (프로젝트 소유)" \
  '{"tool_name":"Edit","tool_input":{"file_path":".claude/settings.json"}}'
t 0 "file_path 가 없는 payload" \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'

# .gitmodules 가 없으면 아무것도 막지 않는다 — 서브모듈 없는 프로젝트
rm .gitmodules
t 0 ".gitmodules 없으면 통과" \
  '{"tool_name":"Edit","tool_input":{"file_path":".claude/skills/branch-policy/SKILL.md"}}'
exit "$fail"
