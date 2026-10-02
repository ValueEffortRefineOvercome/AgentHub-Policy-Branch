---
name: branch-policy
description: 브랜치 이름·수명·머지·충돌 처리 기준. 새 작업을 시작해 분기할 때, 머지하거나 push할 때, 충돌이 났을 때, PR을 올릴 때 사용. "브랜치", "분기", "머지", "충돌", "rebase", "PR", "main에 올려" 요청에도 사용.
---

# 브랜치 정책

## 1. 이름
`<type>/<슬러그>` — type 은 `feat` `fix` `docs` `chore` 넷. 슬러그는 소문자-하이픈.

예: `fix/claude-md-budget`, `docs/branch-policy`

티켓 번호는 안 쓴다 — 트래커가 없다. 생기면 `<type>/<id>-<슬러그>` 로 바꾼다.
type 을 넷으로 묶어둔 이유: 늘리면 어디에 넣을지 매번 고민하게 된다.

## 2. 수명
| 규칙 | 이유 |
|---|---|
| 브랜치 1개 = 작업 1개 | 리뷰 단위가 작업 단위와 같아진다 |
| main 에서만 분기 | 브랜치에서 브랜치를 따면 머지 순서에 의존성이 생긴다 |
| 머지 후 즉시 삭제 | 남은 브랜치는 머지됐는지 아무도 모른다 |
| 하루 넘기면 `git merge main` 으로 받는다 | 오래 떨어져 있을수록 충돌이 커진다 |

**rebase 하지 않는다.** push 된 브랜치를 rebase 하면 force push 가 반드시 필요하고
그건 6절 금지다. squash 머지라 브랜치 내부 커밋은 어차피 버려지므로 머지 커밋이
최종 히스토리에 남지 않는다 — rebase 로 얻을 것이 없다.

### 서브모듈

서브모듈 파일을 고칠 때는 **그 서브모듈 디렉토리에서** 브랜치를 만든다.
루트에 만든 브랜치는 포인터만 옮긴다 — 파일은 바뀌지 않는다.

```bash
git branch --show-current                  # 루트
git -C <서브모듈 경로> branch --show-current   # 서브모듈 — 둘 다 본다
```

한 작업이 서브모듈과 루트에 걸치면 **PR 이 2 개이고 순서가 고정이다.**

1. **서브모듈 PR** — 파일 수정. 머지까지 끝낸다
2. **루트·소비 프로젝트 PR** — `git submodule update --remote <경로>` 로 포인터만 갱신

1 을 건너뛰고 루트에서 서브모듈 파일을 고치면 그 변경은 **어느 저장소에도
커밋되지 않는다.** 서브모듈 작업 트리만 더러워지고 루트는 포인터 불일치로 보인다.

### 소비 프로젝트는 정책 파일을 수정하지 않는다

정책 본문은 소비 프로젝트가 소유하지 않는다. 거기서 고치면 커밋될 곳이 없고
다음 핀 갱신에 덮여 사라진다.

`hooks/block-policy-edit.sh` 를 `Edit|Write` 에 걸면 **실제로 차단된다**(exit 2).
설치법은 그 스크립트 헤더에. **정책 허브에는 설치하지 않는다** — 거기서는 정책
수정이 작업 자체다. 설치 위치가 유일한 구분자다.

막히는 것과 안 막히는 것:

| | |
|---|---|
| 에이전트의 `Edit`·`Write` | **막힌다** |
| 사람이 에디터로 수정 | 안 막힌다. CI 의 서브모듈 변조 탐지가 잡아 머지를 막는다 |
| `Bash` 로 쓰기 (`sed -i`, `cat >`) | 안 막힌다. 같은 CI 가 잡는다 |

서버측 main 차단과 같은 구조다 — 실수는 막고, 의도적 우회는 **머지 지점에서** 막는다.

## 3. 권한 (`/agent-policy` 2절 등급)
| 행위 | 등급 |
|---|---|
| 브랜치 생성, 커밋 | W — 승인 불필요 |
| main 으로 머지, push | **X — 사전 확인** |

X 는 한 번 승인이 다음 번으로 이어지지 않는다. 매번 확인한다.

## 4. 머지
squash 머지. 1 작업 = 1 커밋이라 `git log` 가 작업 목록이 된다.
머지 전 `/pipeline-policy` 1절 게이트 전부 통과 필수.

**PR 을 경유한다.** 로컬에서 main 에 머지하면 그게 곧 main 직접 커밋이라
6절 hook 에 막힌다. 리뷰어가 없어도 PR 을 거친다 — 머지 기록이 남는다.

```bash
git push -u origin <브랜치>                 # W
gh pr create --draft --fill                 # W — 첫 커밋 직후. 작업 상태를 담는다
gh pr ready                                 # W — 작업이 끝났을 때
gh pr merge --squash --delete-branch        # X — 사전 확인
git switch main && git pull --prune         # 로컬 main 동기화 + 죽은 ref 청소
```

draft 로 먼저 만드는 이유와 PR 본문에 무엇을 적는지는 `/task-policy` 4절에 있다 —
다른 PC 에서 작업을 이어받는 유일한 경로다.

`--delete-branch` 가 2절의 "머지 후 즉시 삭제" 를 원격·로컬 양쪽에서 처리한다.
**이 플래그를 빼지 않는다.** GitHub 의 `delete_branch_on_merge` 설정은 **원격만**
지우므로 로컬 브랜치가 남는다. 그리고 남은 로컬 브랜치는 `git branch -d` 로
지워지지 않는다 — squash 머지는 히스토리를 다시 쓰므로 그 커밋이 `main` 의 조상이
아니고, git 은 머지 안 된 것으로 본다. 손으로 치울 때만 **PR 이 MERGED 인지 확인한 뒤**
`-D` 를 쓴다. 6절의 "머지 안 된 브랜치 삭제" 금지는 진짜 안 머지된 경우를 말한다.
`--prune` 이 없으면 삭제된 원격 브랜치의 추적 ref 가 남아 `git branch -r` 에
계속 보인다 — 2절이 지켜졌는지 확인이 안 된다.

### 커밋 메시지
`<type>: <한 줄 요약>` — type 은 1절과 같은 넷. **브랜치명에서 그대로 유도한다.**

```
fix/claude-md-budget   →   fix: CLAUDE.md 상시 예산 초과 수정
docs/branch-policy     →   docs: 브랜치 정책 신설
```

squash 머지라 이 한 줄이 히스토리에 남는 전부다. 본문은 "왜"가 코드에서
안 읽힐 때만 붙인다. 무엇을 바꿨는지는 diff 가 이미 말한다.

## 5. 충돌
`git merge main` 으로 해소한다. **rebase 를 쓰지 않는다** — push 된 브랜치를 rebase 하면
force push 가 필요하고 그건 6절 금지다 (2절 참고).

**에이전트는 충돌을 추측으로 풀지 않는다** — 양쪽 의도가 충돌하면 중단하고 보고.

## 6. 금지
- `main` 직접 커밋·push
  - **예외**: 정책 저장소(`AgentHub`, `AgentHub-Policy-*`) 는 1인 운영이라 `main` 직접
    커밋 허용. 리뷰어가 없는데 브랜치+머지 2회는 순수 오버헤드다.
    **2인째가 들어오면 이 예외를 지운다** — 그때부터 브랜치가 리뷰 지점이 된다.
  - 소비 프로젝트는 예외가 없다. `hooks/block-main-push.sh` 가 차단한다.

- `--force` (`--force-with-lease` 포함. 되돌릴 수 없는 쪽이 항상 더 비싸다)
  - **예외 없다.** 그래서 2·5절이 rebase 대신 `git merge main` 을 쓴다 — rebase 는
    force push 를 요구하므로 이 금지와 양립할 수 없다. 한쪽을 골라야 하고, squash
    머지에서는 rebase 로 얻는 것이 없으므로 merge 를 골랐다
- 머지 안 된 브랜치 삭제

첫 항목은 `hooks/block-main-push.sh` (PreToolUse) 로 **실제 차단**된다.
설치법은 그 스크립트 헤더에 있다. 나머지는 준수에만 의존한다.

### 서버측 차단

| 저장소 | 브랜치 보호 |
|---|---|
| **public** | **된다.** classic protection · rulesets 둘 다. 실측 확인 |
| **private (Free)** | 안 된다. 두 API 가 `403 Upgrade to GitHub Pro` 를 돌려준다 |

정책 저장소(`AgentHub-Policy-*`)는 public 이라 **걸 수 있지만 걸지 않았다** — 위 예외가
`main` 직접 커밋을 허용하고, 걸면 정책 한 줄 고치는 데 PR 이 강제된다.
**2 인째가 들어와 예외를 지울 때 같이 건다.** 그때 쓸 설정은 `enforce_admins: true`,
`required_approving_review_count: 0`, `required_linear_history: true` 다 — 승인 0 이면
혼자서도 자기 PR 을 머지할 수 있고, push 만 막힌다.

private 소비 프로젝트는 여전히 못 건다. 거기서 `main` 에 대해 작동하는 것은:

| | |
|---|---|
| hook | 에이전트의 `main` 커밋·push 를 **예방**한다 |
| CI | push 가 일어난 **뒤에** 실패한다. 사후 탐지이지 예방이 아니다 |

**사람이 터미널에서 직접 `git push origin main` 하는 것은 private 에서 못 막는다.**
막아야 하면 Pro 전환 또는 public 전환이고, 1 인 운영에서는 대체로 무의미하다.
