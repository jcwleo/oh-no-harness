# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Stable](https://img.shields.io/badge/status-stable-green.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | **한국어**

코딩 에이전트에게 또 하나의 런타임은 필요 없습니다. 필요한 건 실제로 읽고 따라갈 수 있는 workflow입니다.

**Oh No Harness**는 **Claude Code**와 **Codex**를 위한 그 workflow입니다: **10개의 stage skill**과 **8개의 role agent**가 모호한 요청을 `interview`에서 `ralplan`, 검증된 `ralph` 실행까지 끌고 가며, npm, tmux, MCP, terminal-only control plane 없이 동작합니다.

두 극단 사이에 있습니다.

- 터미널 한구석을 차지하는 또 하나의 `oh-my-*` 런타임이 아닙니다.
- 단계마다 골라 써야 하는 bare skill 서랍도 아닙니다.

stage skill이 handoff를 조율하고, role agent가 탐색, 계획, 실행, 리뷰, 보안, QA, 검증 같은 전문 패스를 맡는 text-native workflow harness입니다.

- `npm install -g` 없음
- `npx` 댄스 없음
- 살려둬야 할 tmux 창 없음
- 새로 외워야 할 전용 CLI 없음
- 일을 시작하기 전에 붙여야 할 MCP 서버 없음
- app/plugin UI로 가면 무너지는 terminal-only workflow 없음

런타임에서는 일부러 심심합니다. **에이전트가 읽을 수 있는 텍스트 파일**이
전부입니다 — `skills/`와 `skills-claude/`의 플랫폼별 skill wrapper,
`docs/skill-core/`의 공용 workflow core, `docs/providers/`의 유지보수용
회사별 prompt 참고 문서, `agents/`, 얇은 `commands/`, plugin manifest,
그리고 선택적인 Claude Code `SessionStart` 훅 하나.

> [!NOTE]
> Markdown을 읽을 수 있다면 harness의 동작도 확인할 수 있습니다. handoff를 따라갈 수 있다면 workflow도 이해할 수 있습니다.

모호한 요청 정리부터 계획, 실행·검증, 디버깅, 정리까지 10개의 워크플로우를 제공하며, 데몬이나 백그라운드 서비스, 숨겨진 상태 없이 동작합니다.

Oh No Harness는 `1.0.0`부터 semantic versioning을 따릅니다.

## 특징

**🛠 구조**
- **런타임이 아니라 plain text.** npm 패키지도, 프로젝트 전용 CLI도, tmux 세션 매니저도, MCP 서버도 없습니다. 동작은 읽고 diff하고 fork하고 수정할 수 있는 Markdown입니다.
- **호스트 native 설치.** Claude Code와 Codex가 각자의 plugin/skill 시스템으로 로드합니다. Oh No Harness가 관리할 대상을 하나 더 늘리지 않습니다.
- **터미널은 선택 사항.** 설치는 shell에서 할 수 있지만, 일상 workflow는 터미널에 묶이지 않습니다. 같은 Markdown skill이 Claude Code 세션과 Codex App 스타일 plugin UI에서도 맞게 동작합니다.
- **Workflow spine.** 공개 skill은 소프트웨어 개발 단계를 맡고, 내부 agent는 사용자가 외울 새 명령이 아니라 전문 판단 패스로 붙습니다.
- **Skill + 에이전트.** 10개 워크플로우 skill을 8명 역할 에이전트(`explore`, `analyst`, `planner`, `plan-reviewer`, `executor`, `debugger`, `verifier`, `code-reviewer`)가 떠받칩니다.
- **슬래시 ↔ skill 1:1.** `commands/*.md`가 동일한 10개 이름과 argument hint를 노출한 뒤, Claude Code wrapper인 `skills-claude/<name>/SKILL.md`로 위임합니다. Codex는 `skills/<name>/SKILL.md` wrapper를 읽습니다.

| 너무 무거움 | 너무 헐거움 | Oh No Harness |
|---|---|---|
| 옆에서 띄워두는 runtime | 느슨한 skill 선반에서 계속 고르기 | Claude Code / Codex native plugin |
| 프로젝트 CLI 학습 | 매 단계를 손으로 기억 | `interview`, `ralplan`, `ralph` 중심의 작은 stage surface |
| hook, HUD, MCP, tmux 디버깅 | 한 skill이 충분히 해주길 기대 | skill이 role agent로 넘기고 evidence gate로 닫음 |
| 터미널 안에만 머무르기 | GUI host에서 구조를 잃음 | native plugin discovery로 같은 text skill 사용 |
| 플랫폼 운영 | prompt 모음 | 워크플로우를 움직이는 Markdown |

**🔁 워크플로우**
- **소크라테스식 인터뷰.** `/oh-no-harness:interview`가 코드 사실, 리서치 사실, 사용자 판단 질문을 분리해 — 스펙 작성 전에 결정·제약·비범위를 보존합니다.
- **Mode-gated 실행.** 스펙과 계획은 작업을 `LIGHT` / `STANDARD` / `THOROUGH`로 산정하고, Ralph는 기록된 모드에 맞춰 실행합니다 (항상 무거운 루프를 돌리지 않음).
- **Auto-routing.** `/oh-no-harness:auto-routing on` 한 번이면 Claude가 질문·수정 전에 적절한 skill을 먼저 참조하도록 안내합니다 — 숨겨진 상태도, 승인 게이트 우회도 없습니다.

**✨ 사용 경험**
- **자연어 입력.** 작업을 그냥 말로 설명하면 시작됩니다. skill 간 전환은 명시적으로 유지됩니다.
- **`/oh-no-harness:ultrawork`은 end-to-end 옵션.** 인터뷰 → 계획 → 실행 → 검증을 한 요청으로 묶고 싶을 때 쓰는 opt-in 경로입니다.

## 설치

저장소 루트는 마켓플레이스이고, 실제 플러그인 source는
`plugins/oh-no-harness/` 아래에 있습니다.

`npm install`, `npx`, tmux bootstrap, 독립 실행형 `oh-no` 바이너리, MCP 서버, setup daemon, runtime doctor가 필요 없습니다. 아래 터미널 명령은 설치 경로일 뿐이고, workflow 자체는 Codex App 같은 GUI/plugin surface를 포함해 호스트 안에서 동작합니다.

> [!TIP]
> 에이전트가 이미 읽는 곳에 plugin으로 설치하고, Claude Code에서 더 강한 가이드를 원하면 auto-routing을 켠 뒤, 호스트 안에서 바로 작업하세요.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

설치 후 `/oh-no-harness:auto-routing on`을 한 번 실행하세요. 이후에는 작업을 자연어로 설명하기만 하면 Claude Code가 질문·계획·수정·완료 선언 전에 적절한 skill을 먼저 확인하도록 안내합니다.

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

마켓플레이스를 추가합니다:

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

그 다음 Codex에서 `/plugins`를 열거나 Codex App의 plugin 사이드바에서,
`oh-no-harness` 마켓플레이스의 **Oh No Harness**를 선택해 설치합니다.
플러그인은 `oh-no-harness@oh-no-harness`로 표시됩니다.

<details>
<summary>이후 업데이트</summary>

```sh
codex plugin marketplace upgrade oh-no-harness
```

</details>

## 사용법

각 워크플로우는 플러그인 네임스페이스가 붙은 슬래시 명령으로 호출합니다. Claude Code에서는 `commands/*.md` 래퍼가 autocomplete hint를 추가한 뒤 matching skill을 읽습니다. 손에 든 입력 형태에 맞게 고르세요:

| Skill | 언제 쓰면 좋은가 |
|---|---|
| `/oh-no-harness:interview <모호한 작업>` | 요청이 막연하거나 요구사항이 부족할 때 — `.oh-no/specs/`에 임시 Ralph 모드 포함 스펙이 저장됩니다. |
| `/oh-no-harness:ralplan <작업 또는 스펙>` | 광범위·고위험·다파일 작업이라 코딩 전 계획·승인이 필요할 때 — `.oh-no/plans/`에 저장됩니다. |
| `/oh-no-harness:ralph <계획 또는 티켓>` | 수용 기준이 명확한 구체적인 작업 — 모드를 읽고 검증까지 실행합니다. |
| `/oh-no-harness:ultrawork <요청>` | End-to-end: interview → ralplan → ralph → verification 한 흐름. |
| `/oh-no-harness:test-driven-development <변경>` | 명시적인 TDD/test-first 요청 또는 Ralph/debugging 실행 내부 게이트 — 일반 구현은 Ralph로 라우팅합니다. |
| `/oh-no-harness:systematic-debugging <장애>` | 실패한 테스트, 크래시, 또는 원인을 모를 때. |
| `/oh-no-harness:verification-before-completion` | "완료" / "수정됨" / "준비됨" 선언 전 — 새 증거를 요구합니다. |
| `/oh-no-harness:simplify` | 구현 후 품질 정리 - 재사용, 단순화, 효율, 적절한 추상화 깊이를 점검합니다. |
| `/oh-no-harness:auto-routing on\|off\|status` | skill 선택 가이드 강도를 토글 (Claude Code 한정). |
| `/oh-no-harness:using-oh-no-harness` | 최상위 인덱스 — 다른 skill이 기억나지 않을 때 여기서 시작. |

어느 걸 쓸지 모르겠다면 그냥 작업을 자연어로 적으세요 — harness가 요청 형태에 맞춰 라우팅합니다. 한 요청으로 전 과정을 묶고 싶을 때만 `/oh-no-harness:ultrawork`을 쓰면 됩니다.

일반적인 단계 흐름:

1. 사용자가 작업을 설명하면, 목표가 아직 흐릿할 때 Claude Code나 Codex가 `interview`를 선택합니다.
2. 사용자가 스펙을 승인하면, 구현 계획이 필요한 경우 호스트 에이전트가 `ralplan`을 호출합니다.
3. 사용자가 계획을 승인하면, 호스트 에이전트가 일반 `ralph`로 실행할지 end-to-end `ultrawork`로 진행할지 묻습니다. 승인된 Ralph handoff는 계획에 분리 가능한 role이 있으면 기본적으로 parallel-capable입니다.
4. `ralph`가 실행, 검증, 리뷰, 완료 보고를 진행합니다. 사용자가 Planner, Plan-Reviewer, Executor, Verifier 같은 내부 역할 에이전트를 직접 고를 필요는 없습니다. 선택된 workflow가 허용할 때 호스트 에이전트가 알아서 사용합니다.

## Auto Routing (Claude Code)

기본은 off. 한 번 켜두면 `SessionStart` 훅이 Claude에게 응답/질문/수정 전에 항상 이 skill들을 먼저 참고하도록 안내합니다:

```text
/oh-no-harness:auto-routing on
```

토글 후에는 Claude Code를 재시작하거나 `/clear` 하세요. 설정은 플러그인 업데이트 후에도 유지됩니다.

## 개인정보 및 동작

- compact `SessionStart` 안내와 좁은 `UserPromptSubmit` Ralph adapter 훅만 사용 — `PreToolUse`/`PostToolUse` 미사용.
- npm 런타임 없음, 별도 CLI 프로세스 없음, tmux 프로세스 없음, MCP 서버 없음.
- **네트워크 호출 없음**, **텔레메트리 없음**.
- 플러그인 디렉토리와 `~/.claude/plugins/data/<oh-no-harness-*>/` (해당 레이아웃이 없는 호스트에선 `~/.config/oh-no-harness/`)만 읽고 씁니다 (auto-routing 플래그용).
- 모든 command, skill, agent는 일반 Markdown입니다. 데몬도, 백그라운드 프로세스도 없습니다.

## 산출물

작업 결과물은 `.oh-no/` 아래에 저장됩니다:

- `.oh-no/specs/` — interview 산출물
- `.oh-no/plans/` — ralplan 산출물
- `.oh-no/sessions/` — 일시적인 워크플로우 상태
- `.oh-no/worktrees/` — 프로젝트 내부 Ralph/Ultrawork 작업 worktree
- `.oh-no/test-runs/` — harness 테스트 로그

## 개발

유지보수자와 기여자는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요. 로컬 체크아웃을 직접 설치하는 방법, 검증 단계, 라이브 스모크 테스트, 릴리스 워크플로우가 정리돼 있습니다.
