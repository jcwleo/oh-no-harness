# oh-no-harness 설계 노트

이 문서는 새 코딩 툴 하네스를 만들 때 잊지 말아야 할 기준점을 기록한다. 목표는 `oh-my-codex`/`oh-my-claudecode`처럼 런타임 상태와 오케스트레이션이 큰 시스템이 아니라, `superpowers`처럼 가볍고 설치/이해/유지가 쉬운 스킬 중심 하네스다.

## 1. 제품 방향

### 만들고 싶은 것

- **가벼운 스킬/부트스트랩 하네스**: 동작의 대부분은 사람이 읽을 수 있는 Markdown 스킬에 둔다.
- **쓰기 쉬운 설치 단위**: repo root가 Codex와 Claude Code의 plugin root가 되도록 유지하고, 도구별 metadata는 얇게 둔다.
- **명시적인 워크플로 가드레일**: 브레인스토밍, 계획 작성, 실행, 디버깅, 검증 같은 반복 가능한 행동 계약을 스킬로 제공한다.
- **낮은 유지보수 비용**: 복잡한 상태 저장, 데몬, tmux/team 런타임, HUD, 세션 재생 같은 기능은 기본 설계에서 제외한다.

### 만들지 않을 것

- 기본 `.oh-no/state` 런타임 DB 또는 세션 저널.
- 항상 켜지는 MCP 서버, 백그라운드 데몬, tmux 기반 팀 런타임.
- 도구별 metadata나 hook 안에 숨어 있는 정책 로직.
- 설치만으로 외부 서비스에 쓰기 작업을 하는 흐름.

## 2. 조사 기준 스냅샷

2026-05-09 기준으로 아래 오픈소스 하네스를 비교했다.

| Repo | Snapshot | 분석 포인트 |
| --- | --- | --- |
| `Yeachan-Heo/oh-my-codex` | `09d6fd05cd10`, v0.16.3 | 기능이 풍부하지만 상태/런타임/오케스트레이션 표면이 큼. 새 하네스의 기본값으로는 과함. |
| `Yeachan-Heo/oh-my-claudecode` | `679b418f3240`, v4.13.7 | Claude Code 쪽 대형 오케스트레이션 패턴 참고 대상. 새 하네스에는 필요한 설치/스킬 패키징 아이디어만 선별. |
| `obra/superpowers` | `f2cbfbefebbf`, v5.1.0 | 핵심 참조 모델. 스킬 Markdown + 얇은 플러그인/훅 부트스트랩으로 동작. |

Superpowers에서 근거로 삼은 주요 파일:

- `.codex-plugin/plugin.json`
- `.claude-plugin/plugin.json`
- `hooks/hooks.json`
- `hooks/run-hook.cmd`
- `hooks/session-start`
- `scripts/sync-to-codex-plugin.sh`
- `skills/using-superpowers/SKILL.md`
- `skills/using-superpowers/references/codex-tools.md`
- `skills/brainstorming/SKILL.md`
- `skills/writing-plans/SKILL.md`
- `skills/verification-before-completion/SKILL.md`

핵심 결론: 새 하네스는 OMX/OMC식 런타임 오케스트레이터가 아니라 Superpowers식 **스킬 번들 + 세션 부트스트랩 + 얇은 host metadata**여야 한다.

## 3. Superpowers 동작 모델

### 3.1 공통 핵심: `skills/*/SKILL.md`

Superpowers의 본체는 `skills/<skill-name>/SKILL.md` 파일들이다.

- 각 스킬은 frontmatter의 `name`, `description`으로 발견된다.
- `description`은 언제 스킬을 써야 하는지에 대한 라우팅 힌트다.
- 본문은 에이전트가 따라야 할 절차/원칙/검증 조건을 담는다.
- 스킬끼리는 다음에 사용할 스킬을 문서로 연결한다. 별도 상태 머신이 아니라 문서 체인이다.

대표 워크플로 체인:

```text
brainstorming -> writing-plans -> executing-plans 또는 subagent-driven-development -> verification-before-completion
```

새 하네스에서는 이 체인을 그대로 노출하지 않고 아래처럼 축약한다.

```text
clarify -> planning [--ral] -> ralph -> verify
```

`finish`는 별도 top-level skill로 두지 않는다. `ralph`/`verify`의 최종 보고 단계가 변경 요약, 검증 증거, 남은 리스크, 선택적 follow-up을 포함한다.

### 3.2 세션 부트스트랩: Superpowers `using-superpowers`에서 배울 점

`using-superpowers`는 Superpowers의 부트스트랩 계약이다.

- 대화 시작 시 적용되어야 하는 메타 스킬이다.
- 요청과 관련된 스킬이 있으면 응답/작업 전에 먼저 그 스킬을 사용하라고 지시한다.
- “1%라도 관련 가능성이 있으면 스킬을 확인한다”는 강한 라우팅 원칙을 둔다.
- 사용자 지시가 스킬 지시보다 우선한다.
- Claude Code와 Codex의 도구 차이를 매핑한다. 예: Claude의 `Task`/`TodoWrite`/`Skill` 개념을 Codex의 `spawn_agent`/`update_plan`/native skills로 대응시킨다.

새 하네스에는 동일한 역할이 필요하지만, 이것을 사용자 호출 스킬로 만들지는 않는다. 대신 `bootstrap/oh-no.md`에 세션 지침을 두고 host hook이 가능할 때 주입한다.

## 4. Claude Code 설치/동작 방식

Superpowers의 Claude Code 쪽 강점은 **세션 시작 훅으로 메타 스킬을 강제 주입**한다는 점이다.

관련 구성:

```text
.claude-plugin/plugin.json
hooks/hooks.json
hooks/run-hook.cmd
hooks/session-start
skills/using-superpowers/SKILL.md
```

동작 흐름:

1. Claude Code 플러그인을 설치한다.
2. 플러그인 루트의 `skills/`와 `hooks/`가 Claude Code 플러그인 규약으로 발견된다.
3. `hooks/hooks.json`이 `SessionStart` 이벤트(`startup`, `clear`, `compact`)에 `hooks/run-hook.cmd session-start`를 연결한다.
4. `run-hook.cmd`는 Unix/Windows 양쪽에서 실제 훅 스크립트를 실행하기 위한 얇은 호환 래퍼다.
5. `hooks/session-start`는 `skills/using-superpowers/SKILL.md` 내용을 읽어서 `additionalContext` 형태로 Claude Code 세션에 주입한다.
6. 결과적으로 Claude Code에서는 첫 사용자 프롬프트 이전부터 메타 스킬 지시가 컨텍스트에 들어간다.

새 하네스의 Claude plugin root 원칙:

- `bootstrap/oh-no.md`를 SessionStart 훅으로 주입한다.
- 훅은 메타 스킬을 읽어 추가 컨텍스트로 반환하는 일만 한다.
- 훅에 상태 저장, 라우팅 엔진, 네트워크 호출을 넣지 않는다.
- Windows 호환이 필요하면 Superpowers처럼 wrapper만 둔다.

## 5. Codex 설치/동작 방식

Superpowers의 Codex 쪽은 Claude와 다르게 훅 부트스트랩이 아니라 **Codex plugin manifest의 skills 등록**에 가깝다.

관련 구성:

```text
.codex-plugin/plugin.json
skills/
scripts/sync-to-codex-plugin.sh
```

Codex 플러그인 manifest의 핵심은 다음 형태다.

```json
{
  "skills": "./skills/",
  "interface": {
    "displayName": "...",
    "capabilities": ["Interactive", "Read", "Write"]
  }
}
```

동작 흐름:

1. Codex 플러그인을 설치한다.
2. `.codex-plugin/plugin.json`의 `skills` 경로가 스킬 루트로 등록된다.
3. Codex는 스킬의 이름/설명/경로를 컨텍스트에 노출하고, 필요할 때 전체 `SKILL.md`를 로드한다.
4. 사용자는 `/skills` 또는 `$skill-name`으로 명시 호출할 수 있고, 모델/라우터가 `description`을 보고 암시적으로 선택할 수도 있다.

중요한 차이:

- Superpowers Codex manifest에는 Claude의 `SessionStart` 훅에 해당하는 강제 부트스트랩 장치가 보이지 않는다.
- 따라서 Codex에서는 `using-superpowers`가 “대화 시작 시 사용”이라는 description으로 선택될 수는 있지만, Claude처럼 첫 프롬프트 전에 항상 주입된다는 보장은 약하다.

새 하네스의 Codex plugin root 원칙:

- `.codex-plugin/plugin.json`은 `skills` 등록과 UI metadata만 담당한다.
- 신뢰성이 필요하면 repo-local `AGENTS.md` 또는 짧은 bootstrap prompt를 보조 경로로 둔다.
- Codex 스킬 목록에는 사용자 호출 가능한 canonical workflow skill만 노출한다.
- Codex metadata에는 별도 상태 머신이나 hook-like 런타임을 만들지 않는다.

## 6. Superpowers sync/배포 모델에서 배울 점

Superpowers는 Codex 배포용 동기화 스크립트로 upstream repo 내용을 Codex plugin marketplace repo에 복사한다.

배울 점:

- 원본 repo는 여러 도구용 파일을 포함할 수 있다.
- 배포 스크립트는 필요한 파일만 선별해서 내보낸다.
- Codex 배포물에는 Claude 전용 `.claude-plugin/`, hooks, tests 등 불필요한 파일을 제외한다.
- 도구별로 소유권이 다른 파일은 동기화 시 보존 규칙을 둔다.

새 하네스에는 처음부터 복잡한 marketplace sync가 필요하지 않다. repo root를 직접 plugin root로 만들고, 선택적으로만 dist bundle을 만든다.

## 7. 제안 구조

```text
oh-no-harness/
  README.md
  bootstrap/
    oh-no.md
  docs/
    oh-no-harness-design.md
  skills/
    clarify/
      SKILL.md
    planning/
      SKILL.md
    ralph/
      SKILL.md
    debug/
      SKILL.md
    verify/
      SKILL.md
  agents/
    planner.md
    architect.md
    critic.md
    executor.md
    verifier.md
    code-reviewer.md
    explore.md
    analyst.md
    debugger.md
    test-engineer.md
  .codex/
    agents/
      *.toml
  .codex-plugin/
    plugin.json
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json
    run-hook.cmd
    session-start
  scripts/
    validate-skills
    sync-adapters
  templates/
    spec.md
    plan.md
    progress.md
    verify.md
  tests/
    acceptance/
      README.md
```

구조 원칙:

- `bootstrap/oh-no.md`는 세션 시작 지침의 source of truth다.
- `skills/`는 사용자 호출 workflow의 source of truth다.
- `agents/`는 Claude-ready role/subagent prompt의 source of truth다.
- `.codex/agents/`는 Codex native custom-agent template의 source of truth다.
- repo root 자체가 Claude Code와 Codex의 plugin root다. `.codex-plugin/`, `.claude-plugin/`, `hooks/`는 얇은 host metadata/부트스트랩 레이어다.
- `scripts/`는 검증/복사만 수행한다. 런타임 상태를 소유하지 않는다.
- `tests/acceptance/`는 “새 세션에서 스킬이 실제로 적용되는가”를 검증한다.
- 실제 호출 가능한 스킬 이름은 canonical 이름만 둔다. legacy 기능명은 조사/비교 문맥에서만 사용하고, 설치되는 호출명으로 만들지 않는다.
- Superpowers처럼 공통 core를 repo root에 두고 host metadata를 얇게 유지한다. 별도 `adapters/` 디렉토리를 source of truth로 두지 않는다.

## 8. 필요한 기능 요구사항 분석

사용자가 명시한 필요 기능은 아래 두 source에서 가져오되, clarification 기능은 하나로 합친다.

1. `oh-my-claudecode`, `oh-my-codex`에서 가져올 기능
   - `deep-interview`의 고강도 요구사항 clarification 기능
   - `ralplan`의 합의형 계획 기능
   - `ralph`
   - planning/`ralph` 실행에 필요한 역할 에이전트: `planner`, `architect`, `critic`, `executor`, `verifier`, `explore`, `analyst`, `debugger`, `test-engineer` 등
2. `superpowers`에서 가져올 기능
   - `brainstorming`의 가벼운 design clarification 기능

중요한 설계 판단: 이 기능들을 OMX/OMC 런타임 그대로 복제하지 않는다. 새 하네스는 **기능적 등가물**만 가져온다. 즉, 무거운 stop hook, HUD, tmux/team state, `.omx`/`.omc` 지속 상태 머신을 기본값으로 들여오지 않고, 사람이 읽을 수 있는 `SKILL.md`와 역할 프롬프트로 재구성한다.

분석 근거로 삼은 주요 파일:

- Superpowers `skills/brainstorming/SKILL.md`: creative work 전 hard gate, one-question flow, design/spec/user-review/writing-plans handoff.
- Superpowers `skills/test-driven-development/SKILL.md`: 구현 중 RED → GREEN → REFACTOR 순서와 regression proof를 강제.
- Superpowers `skills/subagent-driven-development/SKILL.md`: plan task 단위 fresh executor lane과 spec compliance review → code quality review 순서 참고. 단, 새 하네스에서 `SDD`라는 약어는 **spec-driven development**를 뜻한다.
- OMX `skills/deep-interview/SKILL.md`: intent-first Socratic loop, ambiguity threshold, non-goals/decision-boundary gate, `.omx/specs/` handoff.
- OMC `skills/deep-interview/SKILL.md`: Ouroboros-style ambiguity scoring, topology/ontology gates, `.omc/specs/` handoff, explicit execution approval.
- OMX/OMC `skills/ralplan/SKILL.md` and `skills/plan/SKILL.md`: Planner → Architect → Critic consensus planning, RALPLAN-DR, ADR, no direct execution.
- Superpowers `skills/writing-plans/SKILL.md`: approved spec/design을 file map, bite-sized task, verification step이 있는 실행 계획으로 변환.
- OMX/OMC `skills/ralph/SKILL.md`: persistence loop, plan/PRD grounding, verification, reviewer approval, cleanup/retry loop.
- OMX `prompts/architect.md`, `prompts/critic.md`; OMC `agents/architect.md`, `agents/critic.md`, `agents/code-reviewer.md`: read-only architecture/review contracts used by `planning --ral` and `ralph`.

### 8.1 `brainstorming`과 `deep-interview`는 하나의 `clarify`로 합친다

두 기능은 모두 구현 전에 의도와 경계를 명확히 하는 선행 clarification 단계다.

공통점:

- 구현 전에 실행한다.
- 현재 프로젝트/코드베이스 맥락을 먼저 확인한다.
- 사용자를 한 번에 몰아붙이지 않고 질문을 한 개씩 한다.
- 목적, 제약, 성공 기준을 확인한다.
- 구현으로 넘어가기 전에 spec/design artifact를 만든다.
- 다음 단계는 plan/execution이지, 바로 무작정 코딩이 아니다.

차이점:

| 항목 | Superpowers `brainstorming` | OMX/OMC `deep-interview` |
| --- | --- | --- |
| 기본 성격 | 창의적 설계 구체화 | 요구사항 모호성 제거 |
| 트리거 | 기능 생성, 컴포넌트 구축, 동작 변경 등 creative work 전반 | 모호한 요청, “don't assume”, “interview me”, 고위험/고복잡도 요청 |
| 질문 방식 | 자연스러운 대화, multiple choice 선호, 하나씩 질문 | 소크라테스식 압박 질문, 가장 약한 clarity dimension을 계속 겨냥 |
| 설계 탐색 | 2-3개 접근안을 제시하고 추천안을 설명 | 숨은 가정, non-goals, decision boundaries, acceptance criteria를 압박 |
| 게이트 | 사용자에게 design section을 보여주고 approval을 받음 | ambiguity threshold, non-goals, decision boundaries 충족 전 handoff 금지 |
| 산출물 | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` 스타일 design spec | `.omx/specs/deep-interview-{slug}.md` 또는 `.omc/specs/deep-interview-{slug}.md` 스타일 requirements spec |
| 다음 단계 | `writing-plans`만 호출 | `planning --ral`, `autopilot`, `ralph`, `team` 등으로 handoff |
| 무거운 요소 | spec commit/user review까지 요구 | ambiguity scoring, topology/ontology, challenge modes, persistent state |

새 하네스에서의 결론:

- 별도 `brainstorming`/`deep-interview` 스킬을 만들지 않는다.
- 하나의 `skills/clarify/SKILL.md`가 두 역할을 profile로 흡수한다.
- Superpowers `brainstorming`의 동작은 `clarify --design` profile에 흡수한다.
- OMX/OMC `deep-interview`의 동작은 `clarify --deep` profile에 흡수한다.
- 기본 profile은 Superpowers식 가벼운 design clarification이다.
- 고위험/고모호성/명시 deep-interview 요청에서만 Socratic pressure를 강화한다.
- 공통 clarification 원칙은 한 곳에 둔다.
  - codebase facts는 에이전트가 직접 조사한다.
  - user에게는 판단/선호/경계/위험 허용도만 묻는다.
  - 질문은 한 번에 하나만 한다.
  - 구현 전 산출물을 남긴다.
- `deep-interview`의 수치 scoring/state machine은 `clarify --deep` 내부의 optional rubric으로 축소한다.
  - 유지할 것: intent, outcome, scope, non-goals, decision boundaries, constraints, acceptance criteria, pressure pass.
  - 버릴 것: hidden persistent mode state, stop-hook lock, HUD 연동, topology/ontology hard gate.

추천 스킬 구조:

```text
skills/
  clarify/
    SKILL.md        # adaptive clarification: --design 기본, --deep 고강도
```

`clarify`는 내부적으로 세 profile을 가진다.

| Profile | 선택 기준 | 목적 | 종료 조건 |
| --- | --- | --- | --- |
| `--design` | 새 기능/창의적 설계/UX/동작 변경 | Superpowers식 자연스러운 아이디어 구체화, 2-3개 접근안과 추천안 제시 | 사용자가 design 방향을 승인하고 spec이 충분히 구체화됨 |
| `--standard` | 기본값 또는 애매한 feature/refactor | design + requirements를 균형 있게 정리 | scope, constraints, success criteria, non-goals가 명시됨 |
| `--deep` | “don't assume”류 요청, 고위험/고모호성 | 숨은 가정/decision boundaries/acceptance criteria를 압박 | non-goals와 decision boundaries가 명시되고 residual risk가 기록됨 |

Profile 선택 규칙:

1. 새 기능/창의적 설계/UX/동작 변경은 `clarify --design`.
2. 일반 feature/refactor clarification은 `clarify --standard`.
3. “don't assume”류 요청, 고위험/고모호성 요청은 `clarify --deep`.
4. 대화 중 모호성이나 실패 비용이 커지면 `clarify --standard` 또는 `--deep`으로 승격할 수 있다.
5. 반대로 `--deep` 중에도 요구가 충분히 작고 명확해지면 spec만 남기고 빨리 종료한다.

산출물은 하나로 통일한다.

```text
docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md
```

문서 안에 `profile: design|standard|deep`을 기록한다. 그래서 downstream `planning`/`ralph`는 스킬 이름이 아니라 artifact의 clarity 수준과 acceptance criteria를 보고 이어받는다.

### 8.2 `planning`: 기본 계획과 RAL 합의 계획을 하나로 합친다

OMC의 합의형 계획과 Superpowers의 실행 계획 작성 개념은 하나의 `planning` skill로 합친다.

핵심 판단:

- 스킬 이름은 `planning` 하나만 둔다.
- 기본 호출은 lightweight implementation planning이다.
- `--ral`을 붙이면 OMC `ralplan`처럼 Planner → Architect → Critic → ADR 과정을 거친다.
- 합의형 계획은 `planning --ral`로만 호출한다.
- 실행 계획 작성은 기본 `planning`으로만 호출한다.
- `planning --ral`은 기본 `planning`을 대체하지 않는다. 기본 plan output에 consensus gate를 추가한 superset이다.

```text
planning              # 기본 실행 계획: file map, task breakdown, tests, verification
planning --ral        # 기본 실행 계획 + RALPLAN-DR + Architect + Critic + ADR
```

기본 `planning`이 유지할 핵심:

- clarify/spec/design artifact 또는 사용자 요청을 입력으로 받는다.
- 작업 파일/모듈 경계를 먼저 매핑한다.
- implementation task를 작고 검증 가능한 단위로 나눈다.
- 각 task는 다음을 포함한다.
  - task ID (`T-001` 형식)
  - 연결된 spec ID (`AC-*`, `INV-*`, `DEC-*`)
  - 목적
  - 대상 파일
  - 변경 요약
  - 테스트/검증 명령
  - acceptance criteria
  - 의존 task
- 기본 계획은 `architect`/`critic`을 반드시 호출하지 않는다.
- 기본 계획은 전략적 논쟁보다 실행 가능성, 파일 경계, 검증 가능성에 집중한다.
- behavior change, bugfix, refactor task에는 TDD step을 포함한다.
  - failing test 또는 재현 스크립트 작성
  - red 확인
  - 최소 구현
  - green 확인
  - 필요한 경우 refactor
- TDD가 현실적으로 맞지 않는 task라면 그 이유와 대체 검증 방법을 plan에 명시한다.

`planning --ral`이 유지할 핵심:

- `planner`가 plan 초안을 만든다.
- plan에는 RALPLAN-DR 요약이 들어간다.
  - Principles 3-5개
  - Decision Drivers top 3
  - viable options 2개 이상과 pros/cons
  - 하나의 선택지만 가능하면 대안 invalidation rationale
- `architect`가 먼저 architecture soundness를 검토한다.
  - favored option에 대한 steelman antithesis
  - 실제 tradeoff tension
  - 가능하면 synthesis path
- `critic`은 architect 뒤에 실행한다. 병렬 실행하지 않는다.
  - principle-option consistency
  - fair alternative exploration
  - risk mitigation clarity
  - testable acceptance criteria
  - concrete verification steps
- critic이 승인하지 않으면 planner가 수정하고 architect → critic loop를 반복한다.
- 최종 plan에는 ADR이 들어간다.
  - Decision
  - Drivers
  - Alternatives considered
  - Why chosen
  - Consequences
  - Follow-ups
- 계획 모드는 실행하지 않는다. 실행은 명시 handoff 후 `ralph` 또는 다른 execution skill이 담당한다.

축소할 것:

- `.omx/state`/`.omc/state` 기반 ralplan lifecycle.
- stop hook enforcement.
- goal-mode, team launch hints, HUD 표시.
- provider override 복잡도.

새 하네스의 `planning`은 “독립 실행 가능한 planning skill”이어야 한다. plan artifact는 repo-visible 경로에 저장한다.

```text
docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md
```

또는 사용자가 선호하는 경로가 있으면 그것을 우선한다.

문서 안에는 `mode: basic|ral`을 기록한다. `ralph`는 이 값을 보고 실행 전 기대 검증 수준을 조정한다.

### 8.3 `ralph`: 지속 실행/검증 기능

`ralph`의 본질은 “완료될 때까지 계속한다”가 아니라, **검증된 완료 전에는 멈추지 않는 실행 루프**다.

유지할 핵심:

- 시작 시 요구사항/plan/spec을 확인한다.
- 모호하면 먼저 `clarify` 또는 `planning`으로 돌린다.
- 실행 중 scope를 임의로 줄이지 않는다.
- 독립 작업은 가능한 경우 역할 에이전트로 병렬화한다.
- verification evidence 없이 완료 선언하지 않는다.
- reviewer sign-off를 둔다.
  - 기본: `architect`
  - 계획/품질 검토가 더 중요하면 `critic`
  - 완료 증거 검증은 `verifier`
- 실패하면 수정하고 같은 기준으로 다시 검증한다.
- 마지막 보고에는 변경사항, 검증 명령/결과, 남은 리스크를 남긴다.

축소할 것:

- 기본 PRD JSON state machine.
- hidden `.omx/state`/`.omc/state` continuation lock.
- mandatory deslop pass.
- automatic `/cancel` lifecycle.
- tmux/ultrawork/team runtime 결합.

새 하네스의 `ralph`는 lightweight execution skill로 정의한다.

```text
skills/ralph/SKILL.md
```

동작 원칙:

1. plan/spec이 있으면 그것을 source of truth로 삼는다.
2. 없고 작업이 명확하면 짧은 실행 checklist를 만든다.
3. 없고 작업이 모호하면 실행하지 말고 clarification/planning으로 handoff한다.
4. 진행 상태는 hidden persistent state가 아니라 현재 세션의 todo/checklist와 명시 artifact에 둔다.
5. 완료 전 verification checklist를 강제한다.

#### SDD/TDD는 context-window를 견디는 내장 execution discipline이다

여기서 `SDD`는 **spec-driven development**다. Superpowers의 `subagent-driven-development`와 약어가 겹치지만, 새 하네스에서는 SDD를 “개발 전에 spec을 명확히 하고, 긴 작업 중에도 그 spec을 계속 source of truth로 재확인하는 방식”으로 정의한다.

SDD의 위치:

- `clarify`는 spec을 만든다. 산출물은 `docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md`다.
- `planning`은 spec을 implementation plan으로 변환한다. 모든 task는 spec의 section/acceptance criteria ID를 참조해야 한다.
- `planning --ral`은 spec과 plan을 함께 검토하고, architecture/critic/ADR 과정에서 spec 위반이나 누락을 먼저 잡는다. 결과물은 기본 `planning` 산출물을 반드시 포함한다.
- `ralph`는 실행 전, 각 task 전, reviewer/verifier 전마다 spec과 plan의 관련 section을 다시 읽는다.
- context window가 커지거나 compaction이 일어나도 에이전트가 기억에 의존하지 않도록, 모든 중요한 결정은 spec 또는 plan artifact에 반영한다.

SDD spec에는 최소한 다음 항목이 있어야 한다.

- Goal / Non-goals
- User-visible behavior
- Scope boundaries
- Constraints and assumptions
- Acceptance criteria with stable IDs
- Invariants that must not regress
- Affected files/modules when known
- Verification matrix
- Open questions / deferred decisions
- Decision log for later scope changes

Stable ID 규칙:

- `AC-001`: 사용자-visible acceptance criterion.
- `INV-001`: 반드시 깨지면 안 되는 invariant/regression guard.
- `DEC-001`: scope나 architecture에 영향을 주는 decision.
- `OQ-001`: 아직 닫히지 않은 open question.
- `T-001`: plan task. 각 task는 하나 이상의 `AC-*` 또는 `INV-*`를 참조한다.
- `VR-001`: verify report entry. 각 entry는 `AC-*`/`INV-*`의 VERIFIED/PARTIAL/MISSING 상태를 기록한다.

SDD guardrail:

- 구현 중 spec과 충돌하는 요구가 발견되면 코드를 먼저 바꾸지 않는다.
- 작은 정정이면 spec의 decision log를 갱신한 뒤 계속한다.
- 큰 scope 변경이면 `clarify` 또는 `planning --ral`로 되돌린다.
- reviewer/verifier는 “테스트 통과”만 보지 않고, spec ID별 충족 여부를 확인한다.

TDD의 위치:

- `planning`은 behavior change, bugfix, refactor task를 만들 때 가능한 한 test-first step을 넣는다.
- `ralph`는 실행 중 test-first가 plan에 있으면 그대로 따른다.
- 기존 테스트 구조가 없거나 UI/문서/config 변경처럼 TDD가 부적합하면, `planning`이 대체 검증 방법을 명시하고 `ralph`가 그 evidence를 수집한다.
- “코드를 먼저 썼으면 무조건 삭제” 같은 Superpowers식 hard law는 기본값으로 가져오지 않는다. 대신 “test-first가 가능한데 생략했다면 이유를 기록하고 reviewer/verifier가 볼 수 있게 한다”를 기본값으로 둔다.

fresh-lane execution의 위치:

- Superpowers의 `subagent-driven-development`는 SDD가 아니라, `ralph` 내부의 선택적 실행 전략으로 취급한다.
- plan task가 서로 독립적이고 도구가 native subagent를 지원하면 `ralph`가 task별 fresh executor lane을 사용할 수 있다.
- 병렬 fresh lane은 파일 소유권이 분리될 때만 사용한다.
  - disjoint file/module scope면 병렬 가능.
  - shared file, shared type, migration, global config는 leader lane 또는 단일 executor가 소유한다.
  - 충돌이 발생하면 병렬을 중단하고 leader가 통합 순서를 재계획한다.
  - 한 번에 띄우는 fresh lane 수는 기본 3개 이하로 제한한다.
- 각 task는 다음 순서를 따른다.
  1. executor가 task를 구현하고 자체 검증한다.
  2. verifier 또는 critic이 spec compliance를 먼저 확인한다.
  3. code quality review가 필요한 경우 critic/code-reviewer가 품질을 본다.
  4. issue가 있으면 같은 task로 돌아가 수정 후 재검증한다.
- subagent를 지원하지 않는 환경에서는 같은 절차를 current-session role-pass로 순차 수행한다.

worktree isolation의 위치:

- Superpowers `using-git-worktrees`의 핵심은 별도 top-level skill로 복제하지 않고, `planning`/`ralph`의 실행 안전 규칙으로 흡수한다.
- 여러 작업, 여러 에이전트, dirty checkout, 겹치는 파일 소유권, long-lived branch가 있으면 mutation-heavy 실행은 격리된 git worktree에서 한다.
- 기본 helper는 `scripts/worktree-start <branch>`다.
  - `.worktrees/`가 있으면 우선 사용하고, 그다음 `worktrees/`, 없으면 `.worktrees/`를 만든다.
  - project-local worktree directory는 gitignore 되어 있어야 한다.
  - dedicated branch를 만들고 setup/baseline check를 실행한다.
- 플러그인으로 다른 repo에서 쓸 때 현재 repo에 `scripts/worktree-start`가 없을 수 있으므로 helper resolution을 명시한다:
  1. project-local `scripts/worktree-start`
  2. 설치된 oh-no harness helper path
  3. 동일 contract의 manual `git worktree add` fallback
- Dirty checkout은 먼저 분류한다. unrelated dirty changes는 main checkout에 남기고, current task에 필요한 dirty changes는 commit/patch 등 명시적 carry-forward step으로 worktree에 옮긴다. 깨끗한 base에서 시작하면서 필요한 변경을 누락하면 안 된다.
- `planning`은 worktree isolation decision과 suggested branch/setup command를 plan에 기록한다.
- `ralph`는 plan이 `required`라고 표시했거나 현재 checkout이 dirty/concurrent-risk이면 실행 전에 worktree를 만들고 progress artifact에 path/baseline result를 기록한다.

즉, 최종 구조는 다음과 같다.

```text
clarify
  └─ SDD spec을 생성

planning
  └─ spec ID에 연결된 task와 TDD/verification step을 생성

ralph
  └─ spec을 계속 재확인하면서 실행하고, 필요 시 fresh executor lane을 사용
```

### 8.4 Artifact chain과 traceability

SDD가 context window를 견디려면 기억이 아니라 artifact chain이 source of truth여야 한다.

```text
clarify
  -> docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md

planning
  -> docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md

ralph
  -> docs/oh-no/runs/YYYY-MM-DD-<slug>-progress.md

verify
  -> docs/oh-no/reports/YYYY-MM-DD-<slug>-verify.md
```

각 artifact의 책임:

| Artifact | 책임 | 필수 traceability |
| --- | --- | --- |
| spec | 무엇을 만들고/만들지 않을지 정의 | `AC-*`, `INV-*`, `DEC-*`, `OQ-*` |
| plan | spec을 실행 가능한 task로 변환 | 각 `T-*`가 관련 `AC-*`/`INV-*`를 참조 |
| progress | 긴 실행 중 현재 상태와 변경 이력을 보존 | 완료/진행/차단 task, 변경 파일, 발견한 spec 충돌 |
| verify report | 완료 주장과 증거를 대조 | 각 `AC-*`/`INV-*`의 VERIFIED/PARTIAL/MISSING |

규칙:

- `ralph`는 각 task 시작 전에 관련 spec/plan section을 다시 읽는다.
- context compaction 이후에는 progress artifact와 남은 task list를 먼저 읽고 재개한다.
- spec이나 plan과 다른 구현 필요성이 발견되면 progress에 기록하고, 필요 시 spec decision log 또는 plan을 갱신한다.
- verify report에서 `PARTIAL` 또는 `MISSING`이 있으면 완료로 보고하지 않는다.

### 8.5 역할 에이전트 카탈로그

`planning --ral`과 `ralph`가 실제로 유용하려면 최소 역할 프롬프트가 필요하다. 단, 역할 프롬프트는 “독립 런타임”이 아니라 각 host가 사용할 수 있는 얇은 텍스트 계약이다.

MVP 필수 역할:

| Role | 목적 | 주 사용처 |
| --- | --- | --- |
| `planner` | 요구를 실행 가능한 plan으로 변환 | `planning` |
| `architect` | 코드/아키텍처를 read-only로 분석하고 tradeoff 검토 | `planning --ral`, `ralph` final review |
| `critic` | plan/design 품질 gate, 빠진 것과 약한 검증을 찾음 | `planning --ral` approval loop |
| `code-reviewer` | spec compliance 이후 코드 품질, 보안, 유지보수성 검토 | `ralph` quality review |
| `executor` | 실제 구현/수정 | `ralph` |
| `verifier` | 완료 주장과 evidence를 대조 | `ralph` completion |
| `explore` | 빠른 repo file/symbol/pattern lookup | `clarify`, `planning` |
| `analyst` | 숨은 요구사항/acceptance criteria 점검 | `clarify --deep`, `planning --ral` |
| `debugger` | root cause 분석 | `ralph` 중 실패/버그 |
| `test-engineer` | 테스트 전략/회귀 검증 | `ralph`, high-risk `planning --ral` |

도구별 패키징:

```text
agents/
  planner.md
  architect.md
  critic.md
  code-reviewer.md
  executor.md
  verifier.md
  explore.md
  analyst.md
  debugger.md
  test-engineer.md
.codex/
  agents/*.toml
.codex-plugin/plugin.json
.claude-plugin/plugin.json
hooks/
  SessionStart bootstrap
```

### 8.5.1 Claude/Codex subagent 배포 결정

Superpowers를 그대로 따를 부분은 **repo root를 plugin root로 만들고 공통 skill 본체를 그대로 노출하는 구조**다. 그러나 Claude Code와 Codex의 native subagent 포맷은 다르므로, root에는 두 포맷을 모두 둔다.

| 항목 | Claude Code | Codex |
| --- | --- | --- |
| native agent 원본 | `agents/*.md` | `.codex/agents/*.toml` |
| 필수 metadata | YAML frontmatter `name`, `description`, `tools` | TOML `name`, `description`, `developer_instructions` |
| skill fallback | 같은 파일 본문을 role prompt로 사용 | `agents/*.md` 또는 current-session role-pass 사용 |
| 자동성 가정 | Claude plugin `agents/`는 native subagent로 쓰일 수 있음 | Codex plugin은 skills 등록이 확실한 계약이며 custom agent TOML은 project/user `.codex/agents` 설치 템플릿으로 취급 |

중요한 판단:

- `scripts/sync-adapters`는 선택적 dist bundle을 만들 뿐 정책을 만들지 않는다. root layout이 source of truth다.
- Claude는 root `agents/`가 바로 sub-agent 후보가 되도록 frontmatter를 가진다.
- Codex는 root `.codex-plugin/plugin.json`으로 skills를 등록하고, root `.codex/agents/*.toml`에 native custom-agent 템플릿을 둔다.
- Codex plugin marketplace가 custom agents를 직접 설치한다는 보장은 설계 불변식으로 삼지 않는다. 그래서 Codex에서도 skill-directed `spawn_agent` 또는 current-session role-pass fallback이 항상 동작해야 한다.
- `description`은 자동/수동 delegation 품질에 직접 영향을 주므로, “언제 써야 하는지”를 구체적으로 적고 `verifier`/`code-reviewer`처럼 완료 품질 gate인 역할에는 `MUST BE USED`를 사용할 수 있다.
- write-capable 역할은 `executor` 하나로 제한한다. reviewer 계열은 read-only 권한과 “Do not implement”를 frontmatter/body 양쪽에서 보존한다.

설계 원칙:

- role prompt는 read/write 권한 경계를 명확히 적는다.
  - `architect`, `critic`, `verifier`, `explore`, `analyst`는 기본 read-only.
  - `executor`만 구현 권한을 가진다.
- `planning --ral`에서는 `architect`와 `critic`을 반드시 순차 실행한다.
- `ralph`에서는 구현 lane과 검증 lane을 분리한다.
- 도구가 native subagent를 지원하지 않으면 같은 prompt를 현재 세션에서 수동 role-pass로 실행할 수 있어야 한다.

### 8.6 새 하네스의 최종 workflow map

```text
새 기능/행동 변경 기본 경로:
clarify --design -> planning -> ralph -> verify

모호하거나 고위험인 경로:
clarify --deep -> planning --ral -> ralph -> verify

이미 명확한 작은 수정:
ralph 또는 직접 executor -> verifier

plan 검토만 필요한 경우:
planning --ral --review 또는 critic
```

MVP에서 가장 중요한 구분:

- `clarify`: profile에 따라 가벼운 brainstorming과 고강도 deep-interview를 모두 담당한다.
- `planning`: 기본 실행 계획과 `--ral` 합의형 계획을 모두 담당한다.
- `ralph`: 실행하고 검증 완료까지 밀고 간다.

## 9. 최소 MVP

1. `bootstrap/oh-no.md`
   - 모든 대화 시작 시 주입할 짧은 세션 지침.
   - 관련 canonical skill을 먼저 고려하라는 규칙.
   - 사용자 지시 우선 원칙.
   - Codex/Claude 도구 차이 매핑.
   - 사용자 호출 스킬이 아니다.

2. `skills/clarify/SKILL.md`
   - `brainstorming`과 `deep-interview`를 통합한 adaptive clarification skill.
   - `--design`: 기본 lightweight brainstorming profile.
   - `--standard`: 일반 feature/refactor clarification profile.
   - `--deep`: 명시 요청 또는 고위험/고모호성 요청에 사용하는 high-rigor profile.
   - MVP에서는 hidden persistent state 없이 spec artifact와 현재 세션 checklist 중심으로 동작.

3. `skills/planning/SKILL.md`
   - 기본 모드: Superpowers `writing-plans`처럼 실행 가능한 file/task/test/verification plan을 만든다.
   - `--ral` 모드: OMC `ralplan`처럼 Planner → Architect → Critic consensus planning을 실행한다.
   - `--ral` 모드는 기본 plan output의 superset이며 RALPLAN-DR + ADR output을 포함한다.
   - 실행 전 worktree isolation 필요 여부와 setup command를 기록한다.
   - 계획만 하고 source code를 수정하지 않는다.

4. `skills/ralph/SKILL.md`
   - plan/spec 기반 실행 루프.
   - 필요한 경우 helper resolution을 통해 격리된 worktree에서 mutation-heavy 실행을 시작한다.
   - verification evidence와 reviewer sign-off 전 완료 선언 금지.

5. `skills/debug/SKILL.md`
   - 추측보다 재현, 로그, 코드 경로, 최소 수정.

6. `skills/verify/SKILL.md`
   - 완료 선언 전 claim과 evidence를 맞춘다.

7. `agents/*.md`
   - 최소 `planner`, `architect`, `critic`, `code-reviewer`, `executor`, `verifier`, `explore`, `analyst`, `debugger`, `test-engineer`.

8. Claude plugin root
   - `.claude-plugin/plugin.json`과 `hooks/`를 repo root에 둔다.
   - SessionStart 훅으로 `bootstrap/oh-no.md` 주입.
   - root `agents/*.md`는 Claude native sub-agent frontmatter를 가진다.

9. Codex plugin root
   - `.codex-plugin/plugin.json`로 `skills/` 등록.
   - 필요 시 `AGENTS.md`나 README에 `bootstrap/oh-no.md` 기반 snippet 제공.
   - `.codex/agents/*.toml`에 Codex custom-agent 템플릿을 둔다. 이것은 project/user `.codex/agents` 설치용이며, plugin skills만으로도 동작해야 한다.

10. `templates/*.md`
   - spec/plan/progress/verify 산출물의 기본 구조.
   - context-window, retrieve 누락, checklist 누락을 줄이기 위한 최소 템플릿.

11. `scripts/worktree-start`
   - Superpowers `using-git-worktrees`에서 가져온 conflict isolation helper.
   - worktree directory selection, gitignore safety verification, branch creation, setup detection, baseline verification을 담당한다.

## 10. 검증 기준

### Claude Code acceptance

- fresh session에서 첫 응답 전에 `bootstrap/oh-no.md` 내용이 추가 컨텍스트로 들어간다.
- “brainstorm this feature” 같은 명시 요청은 `clarify --design` profile 적용으로 이어진다.
- 명시 스킬 요청이 있으면 일반 작업보다 스킬 적용이 먼저 일어난다.
- 훅 실패 시에도 플러그인 전체가 깨지지 않고, 스킬 자체는 수동 호출 가능해야 한다.
- 고위험/고모호성 clarification 요청은 `clarify --deep` profile로 라우팅된다.
- `planning`은 plan artifact만 만들고 source code를 수정하지 않는다.
- `planning --ral`은 기본 plan output, `architect`/`critic` 검토, ADR을 모두 포함한다.
- `ralph`는 plan/spec 또는 명확한 checklist 없이 모호한 실행을 시작하지 않는다.
- `ralph`는 긴 실행 중 `docs/oh-no/runs/*-progress.md`를 갱신해 context compaction 이후에도 재개 가능해야 한다.
- root `agents/*.md`는 Claude Code sub-agent frontmatter(`name`, `description`, `tools`)를 포함한다.

### Codex acceptance

- 플러그인 설치 후 `/skills`에서 canonical workflow skill만 확인/호출할 수 있다.
- `skills/*/SKILL.md`의 `description`이 암시 선택에 충분히 강하다.
- Codex에서 강제 SessionStart 보장이 없다면 문서에 그 한계를 명확히 적고 bootstrap fallback을 제공한다.
- role agent prompt를 native subagent가 지원하면 사용할 수 있고, 지원하지 않으면 current-session role-pass로 대체할 수 있다.
- root Codex plugin manifest의 `skills` 경로는 `./skills/`이고, native custom-agent 템플릿은 `.codex/agents/*.toml`에 있다.
- Codex custom-agent 템플릿은 `name`, `description`, `developer_instructions`를 포함하고, read-only 역할은 `sandbox_mode = "read-only"`를 명시한다.

### 공통 acceptance

- 스킬은 Markdown만 읽어도 의도를 이해할 수 있다.
- 설치/동기화 스크립트는 dry-run 또는 검증 모드를 가진다.
- 기본 사용에 persistent state가 필요하지 않다.
- spec → plan → progress → verify report가 stable ID로 이어진다.
- `templates/`가 spec/plan/progress/verify 산출물의 필수 필드를 제공한다.
- retrieve 실패는 검색 범위와 unknown을 남기며, 근거 없이 부재를 단정하지 않는다.
- 테스트 없이 “동작한다”고 주장하지 않는다.
- `architect`/`critic`/`code-reviewer`/`verifier`는 read-only 경계를 지킨다.
- `executor`만 source mutation 책임을 가진다.

## 11. 설계 불변식

- **Zero runtime by default**: 기본 사용에는 데몬, tmux, 지속 상태가 없다.
- **Skills are behavior contracts**: 정책과 절차는 스킬 Markdown에 둔다.
- **Host metadata is packaging only**: Codex/Claude 차이는 root metadata와 선택적 bundle script가 흡수하지만 정책을 소유하지 않는다.
- **No hidden state**: 에이전트가 기억해야 할 것은 문서, 스킬, 명시 파일에 둔다.
- **User instruction wins**: 사용자 지시가 스킬 지시보다 우선한다.
- **Evidence before completion**: 완료 선언은 검증 증거와 함께 한다.
- **Root cause over workaround**: 구현/디버그는 임시 우회가 아니라 근본 원인을 분석하고 해결하는 것을 기본값으로 한다.
- **Instrument to understand**: 원인이 명확하지 않으면 안전하고 좁은 로그, tracing, assertion, reproduction script를 추가해 원인을 관측 가능하게 만든 뒤, 완료 전 제거하거나 의도적인 observability로 gate/document한다.
- **No shortcuts / completion integrity**: LLM이 완료한 척하지 않도록 필요한 파일 확인, 테스트, 리뷰, artifact 갱신, 검증을 생략하지 않는다. placeholder, fake confidence, cherry-picked evidence, 숨긴 gap을 금지하고 blocker/gap은 명시한다.
- **Spec drives execution**: plan task와 verify report는 spec의 `AC-*`/`INV-*`를 참조한다.
- **Retrieval before certainty**: 명시된 path/symbol/log/test부터 좁게 확인하고, 찾지 못한 것은 검색 범위와 unknown으로 보고한다.
- **Right-sized planning**: 작은 작업은 inline checklist로 충분할 수 있고, `planning --ral`은 고위험/고트레이드오프 작업에만 기본 적용한다.
- **Templates reduce omission**: spec/plan/progress/verify는 `templates/`를 기준으로 작성해 LLM 누락과 context-window drift를 줄인다.
- **Planning does not mutate product code**: `clarify`, `planning`은 source code를 수정하지 않는다.
- **Reviewers do not implement**: `architect`, `critic`, `code-reviewer`, `verifier`는 read-only reviewer다.
- **Ralph requires a target**: `ralph`는 plan/spec/checklist 없이 모호한 작업을 시작하지 않는다.

## 12. 열려 있는 질문

- Codex 플러그인만으로 `bootstrap/oh-no.md`를 첫 턴 전에 안정적으로 강제할 수 있는가?
  - 현재 설계 가정: 보장하지 않는다. canonical skill descriptions + `AGENTS.md`/README bootstrap snippet을 fallback으로 제공한다.
- Codex plugin marketplace가 `.codex/agents/*.toml`을 자동으로 project/user custom agent로 설치하는가?
  - 현재 설계 가정: 보장하지 않는다. 배포 bundle에는 템플릿을 포함하지만, native custom agent로 쓰려면 project `.codex/agents/` 또는 user `~/.codex/agents/`에 설치하는 경로를 문서화한다.
- marketplace 배포를 언제 도입할 것인가?
  - 현재 설계 가정: 초기에는 local install/copy를 우선한다.
- 스킬 간 연결을 어느 정도까지 강제할 것인가?
  - 현재 설계 가정: 문서 체인으로 충분하다. 상태 머신은 만들지 않는다.
- progress/verify artifact를 repo에 항상 남길지, 큰 작업에서만 남길지?
  - 현재 설계 가정: context window를 넘을 수 있는 작업은 `docs/oh-no/runs/*-progress.md`와 `docs/oh-no/reports/*-verify.md`를 남긴다. 작은 직접 수정은 최종 응답의 evidence summary로 충분할 수 있다.
