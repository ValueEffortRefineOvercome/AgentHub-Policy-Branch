#!/usr/bin/env bash
# block-main-push.sh 자체 검사. main 에서 실행해야 의미가 있다.
H="$(dirname "$0")/block-main-push.sh"
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
exit "$fail"
