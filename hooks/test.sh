#!/usr/bin/env bash
# block-main-push.sh 자체 검사. main 에서 실행해야 의미가 있다.
H="$(cd "$(dirname "$0")" && pwd)/block-main-push.sh"
fail=0
t() {
  printf '  %-46s ' "$2"
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$2\"}}" | bash "$H" 2>/dev/null
  c=$?
  if [ "$c" = "$1" ]; then echo "OK"; else echo "FAIL (exit $c, 기대 $1)"; fail=1; fi
}
case "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" in
  main|master) ;;
  *) echo "  SKIP block-main-push: main 이 아니라 차단 경로를 검사할 수 없다"; exit 0 ;;
esac
t 2 "git push origin main"
t 2 "git -C some/sub commit -am x"
t 2 "git commit -m x"
t 0 "git status"
t 0 "git log --oneline -1"
t 0 "ls -la"
# 4절이 정한 머지 경로는 절대 막히면 안 된다 — 막히면 병합 자체가 불가능해진다
t 0 "gh pr create --fill"
t 0 "gh pr merge --squash --delete-branch"

# 커밋 0개 저장소는 초기 커밋을 허용해야 한다 — 막으면 새 프로젝트를 시작할 수 없다
tmp=$(mktemp -d)
git -C "$tmp" init -q && git -C "$tmp" branch -M main 2>/dev/null || true
printf '  %-46s ' "(커밋0 저장소) git commit -m init"
( cd "$tmp" && echo '{"tool_input":{"command":"git commit -m init"}}' | bash "$H" >/dev/null 2>&1 )
c=$?
rm -rf "$tmp"
if [ "$c" = 0 ]; then echo "OK"; else echo "FAIL (exit $c, 기대 0)"; fail=1; fi

exit "$fail"
