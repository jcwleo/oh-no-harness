# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Beta](https://img.shields.io/badge/status-beta-orange.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | **한국어**

**Claude Code**와 **Codex**를 위한 경량 Markdown 기반 skill harness. 모호한 요청 정리부터 계획, 실행·검증, 디버깅, 정리까지 10개의 워크플로우를 제공하며, 데몬이나 숨겨진 상태 없이 동작합니다.

> ⚠️ **베타 단계** — skill 동작, 명령 형태, 설정 레이아웃이 `0.x` 릴리즈 사이에 바뀔 수 있습니다. 안정성이 필요하다면 태그를 고정하세요 (`--ref v0.2.x`).

## 특징

**🛠 구조**
- **최소 의존성.** tmux도 데몬도 없음 — Claude Code는 `SessionStart` 훅 하나, Codex는 표준 skill 캐시만 사용합니다.
- **Skill + 에이전트.** 10개 워크플로우 skill을 11명 역할 에이전트(`explore`, `analyst`, `planner`, `architect`, `critic`, `executor`, `debugger`, `verifier`, `code-reviewer`, `security-reviewer`, `qa-tester`)가 떠받칩니다.
- **슬래시 ↔ skill 1:1.** `commands/*.md`가 동일한 10개 이름과 argument hint를 노출한 뒤, 실제 지시는 `skills/<name>/SKILL.md`로 위임합니다.

**🔁 워크플로우**
- **소크라테스식 인터뷰.** `/interview`가 코드 사실, 리서치 사실, 사용자 판단 질문을 분리해 — 스펙 작성 전에 결정·제약·비범위를 보존합니다.
- **Mode-gated 실행.** 스펙과 계획은 작업을 `LIGHT` / `STANDARD` / `THOROUGH`로 산정하고, Ralph는 기록된 모드에 맞춰 실행합니다 (항상 무거운 루프를 돌리지 않음).
- **Auto-routing.** `/auto-routing on` 한 번이면 Claude가 질문·수정 전에 적절한 skill을 먼저 참조하도록 안내합니다 — 숨겨진 상태도, 승인 게이트 우회도 없습니다.

**✨ 사용 경험**
- **자연어 입력.** 작업을 그냥 말로 설명하면 시작됩니다. skill 간 전환은 명시적으로 유지됩니다.
- **`/autopilot`은 end-to-end 옵션.** 인터뷰 → 계획 → 실행 → 검증을 한 요청으로 묶고 싶을 때 쓰는 opt-in 경로입니다.

## 설치

이 저장소는 플러그인이자 동시에 플러그인을 배포하는 마켓플레이스입니다.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

설치 후 `/auto-routing on`을 한 번 실행하세요. 이후에는 작업을 자연어로 설명하기만 하면 Claude Code가 질문·계획·수정·완료 선언 전에 적절한 skill을 먼저 확인하도록 안내합니다.

<details>
<summary>Claude Code 내부 대화형 설치</summary>

```text
/plugin marketplace add jcwleo/oh-no-harness
/plugin install oh-no-harness@oh-no-harness
```

</details>

<details>
<summary>이후 업데이트</summary>

```sh
claude plugin marketplace update oh-no-harness
claude plugin update oh-no-harness@oh-no-harness
```

</details>

### Codex

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

그 다음 `/plugins`를 열고 **Oh No Harness**를 선택해 설치합니다. 플러그인은
`oh-no-harness@oh-no-harness`로 표시됩니다.

특정 태그로 고정하거나 갱신:

```sh
codex plugin marketplace add jcwleo/oh-no-harness --ref v0.2.0
codex plugin marketplace upgrade oh-no-harness
```

## 사용법

각 워크플로우는 슬래시 명령으로 호출합니다. Claude Code에서는 `commands/*.md` 래퍼가 autocomplete hint를 추가한 뒤 matching skill을 읽습니다. 손에 든 입력 형태에 맞게 고르세요:

| Skill | 언제 쓰면 좋은가 |
|---|---|
| `/interview <모호한 작업>` | 요청이 막연하거나 요구사항이 부족할 때 — `.oh-no/specs/`에 임시 Ralph 모드 포함 스펙이 저장됩니다. |
| `/ralplan <작업 또는 스펙>` | 광범위·고위험·다파일 작업이라 코딩 전 계획·승인이 필요할 때 — `.oh-no/plans/`에 저장됩니다. |
| `/ralph <계획 또는 티켓>` | 수용 기준이 명확한 구체적인 작업 — 모드를 읽고 검증까지 실행합니다. |
| `/autopilot <요청>` | End-to-end: interview → ralplan → ralph → verification 한 흐름. |
| `/test-driven-development <변경>` | 동작이 바뀌는 모든 수정 — RED / GREEN / REFACTOR 강제. |
| `/systematic-debugging <장애>` | 실패한 테스트, 크래시, 또는 원인을 모를 때. |
| `/verification-before-completion` | "완료" / "수정됨" / "준비됨" 선언 전 — 새 증거를 요구합니다. |
| `/ai-slop-cleaner` | 구현 후 정리 — 일회용 산출물을 제거합니다. |
| `/auto-routing on\|off\|status` | skill 선택 가이드 강도를 토글 (Claude Code 한정). |
| `/using-oh-no-harness` | 최상위 인덱스 — 다른 skill이 기억나지 않을 때 여기서 시작. |

어느 걸 쓸지 모르겠다면 그냥 작업을 자연어로 적으세요 — harness가 요청 형태에 맞춰 라우팅합니다. 한 요청으로 전 과정을 묶고 싶을 때만 `/autopilot`을 쓰면 됩니다.

## Auto Routing (Claude Code)

기본은 off. 한 번 켜두면 `SessionStart` 훅이 Claude에게 응답/질문/수정 전에 항상 이 skill들을 먼저 참고하도록 안내합니다:

```text
/auto-routing on
```

토글 후에는 Claude Code를 재시작하거나 `/clear` 하세요. 설정은 플러그인 업데이트 후에도 유지됩니다.

## 개인정보 및 동작

- `SessionStart` 훅 하나만 사용 — `UserPromptSubmit`/`PreToolUse`/`PostToolUse` 미사용.
- **네트워크 호출 없음**, **텔레메트리 없음**.
- 플러그인 디렉토리와 `~/.claude/plugins/data/<oh-no-harness-*>/` (해당 레이아웃이 없는 호스트에선 `~/.config/oh-no-harness/`)만 읽고 씁니다 (auto-routing 플래그용).
- 모든 command, skill, agent는 일반 Markdown입니다. 데몬도, 백그라운드 프로세스도 없습니다.

## 산출물

작업 결과물은 `.oh-no/` 아래에 저장됩니다:

- `.oh-no/specs/` — interview 산출물
- `.oh-no/plans/` — ralplan 산출물
- `.oh-no/sessions/` — 일시적인 워크플로우 상태
- `.oh-no/test-runs/` — harness 테스트 로그

## 개발

유지보수자와 기여자는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요. 로컬 체크아웃을 직접 설치하는 방법, 검증 단계, 라이브 스모크 테스트, 릴리스 워크플로우가 정리돼 있습니다.
