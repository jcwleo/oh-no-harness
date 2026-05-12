# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Beta](https://img.shields.io/badge/status-beta-orange.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | **한국어**

**Claude Code**와 **Codex**를 위한 경량 Markdown 기반 skill harness. 모호한 요청 정리부터 계획, 실행·검증, 디버깅, 정리까지 10개의 워크플로우를 제공하며, 데몬이나 숨겨진 상태 없이 동작합니다.

> ⚠️ **베타 단계** — skill 동작, 명령 형태, 설정 레이아웃이 `0.x` 릴리즈 사이에 바뀔 수 있습니다. 안정성이 필요하다면 태그를 고정하세요 (`--ref v0.2.x`).

## 설치

이 저장소는 플러그인이자 동시에 플러그인을 배포하는 마켓플레이스입니다.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

대화형 세션에서는 슬래시 명령으로도 가능합니다:

```text
/plugin marketplace add jcwleo/oh-no-harness
/plugin install oh-no-harness@oh-no-harness
```

이후 업데이트:

```sh
claude plugin marketplace update oh-no-harness
claude plugin update oh-no-harness@oh-no-harness
```

### Codex

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

그 다음 `~/.codex/config.toml`에 활성화 블록을 추가합니다:

```toml
[plugins."oh-no-harness@oh-no-harness"]
enabled = true
```

특정 태그로 고정하거나 갱신:

```sh
codex plugin marketplace add jcwleo/oh-no-harness --ref v0.2.0
codex plugin marketplace upgrade oh-no-harness
```

## 사용법

설치 후, skill을 슬래시 명령으로 호출하세요. 손에 든 입력 형태에 맞게 고르면 됩니다:

| Skill | 언제 쓰면 좋은가 |
|---|---|
| `/deep-interview <모호한 작업>` | 요청이 막연하거나 요구사항이 부족할 때. `.oh-no/specs/`에 스펙이 저장됩니다. |
| `/ralplan <작업 또는 스펙>` | 광범위하거나 위험도가 높고, 여러 파일에 걸치는 작업이라 코딩 전 계획·승인이 필요할 때. `.oh-no/plans/`에 계획이 저장됩니다. |
| `/ralph <계획 또는 티켓>` | 수용 기준이 명확한 구체적인 작업. 검증까지 실행합니다. |
| `/autopilot <요청>` | end-to-end 전달: deep-interview → ralplan → ralph → verification을 한 흐름으로. |
| `/test-driven-development <변경>` | 동작이 바뀌는 모든 수정. RED/GREEN/REFACTOR 사이클을 강제합니다. |
| `/systematic-debugging <장애>` | 실패한 테스트, 크래시, 또는 원인을 모를 때. |
| `/verification-before-completion` | "완료" / "수정됨" / "준비됨"을 선언하기 전에. 새 증거를 요구합니다. |
| `/ai-slop-cleaner` | 구현 후, 전달 전에. 일회용 산출물을 정리합니다. |
| `/auto-routing on\|off\|status` | skill 선택 가이드 강도를 토글 (Claude Code 한정). |
| `/using-oh-no-harness` | 최상위 인덱스 — 다른 skill이 기억나지 않을 때 여기서 시작. |

어느 걸 쓸지 모르겠다면 그냥 작업을 자연어로 적으세요. 요청 형태에 맞춰 harness가 알아서 라우팅합니다.

## Auto Routing (Claude Code)

기본은 off. 한 번 켜두면 `SessionStart` 훅이 Claude에게 응답/질문/수정 전에 항상 이 skill들을 먼저 참고하도록 안내합니다:

```text
/auto-routing on
```

토글 후에는 Claude Code를 재시작하거나 `/clear` 하세요. 설정은 플러그인 업데이트 후에도 유지됩니다.

## 개인정보 및 동작

- `SessionStart` 훅 하나만 사용 — `UserPromptSubmit`/`PreToolUse`/`PostToolUse` 미사용.
- **네트워크 호출 없음**, **텔레메트리 없음**.
- 플러그인 디렉토리와 `${CLAUDE_PLUGIN_DATA}` (또는 `~/.config/oh-no-harness/`)만 읽고 씁니다 (auto-routing 플래그용).
- 모든 skill과 agent는 일반 Markdown입니다. 데몬도, 백그라운드 프로세스도 없습니다.

## 산출물

작업 결과물은 `.oh-no/` 아래에 저장됩니다:

- `.oh-no/specs/` — deep-interview 산출물
- `.oh-no/plans/` — ralplan 산출물
- `.oh-no/sessions/` — 일시적인 워크플로우 상태
- `.oh-no/test-runs/` — harness 테스트 로그

## 개발

유지보수자와 기여자는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요. 로컬 체크아웃을 직접 설치하는 방법, 검증 단계, 라이브 스모크 테스트, 릴리스 워크플로우가 정리돼 있습니다.
