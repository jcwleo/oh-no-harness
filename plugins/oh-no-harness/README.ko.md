# Oh No Harness Plugin Package

이 디렉터리는 `oh-no-harness` 플러그인의 source package입니다.

사용자를 위한 canonical 문서는 저장소 루트에 있습니다.

- [README](../../README.md)
- [한국어 README](../../README.ko.md)

플러그인 개발 규칙은 이 패키지 옆 문서에 있습니다.

- [Contributing](CONTRIBUTING.md)

이 패키지는 Claude Code와 Codex가 사용하는 플러그인 manifest와 runtime
surface, 공개 npm으로 배포되는 OpenCode runtime, 그리고 유지보수 참고
문서를 담고 있습니다.

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `package.json` (공개 `oh-no-harness` OpenCode npm 패키지)
- `skills/` (생성된 Codex-facing runtime skill 문서 10개)
- `skills-claude/` (생성된 Claude Code-facing runtime skill 문서 12개)
- `skills-opencode/` (생성된 OpenCode-facing runtime skill 문서 11개)
- `docs/skill-core/` (공용 workflow core)
- `docs/platforms/` (platform 공통 runtime 지침과 skill별 overlay)
- `docs/agent-core/` (플랫폼 공통 role prompt 본문과 agent 동작 source of truth)
- `docs/platforms/codex-agents/` (생성된 선택적 Codex custom-agent 템플릿)
- `docs/providers/` (platform 문서를 유지보수하기 위한 회사별 prompt guide 참고 문서, 실행 경로 아님)
- `commands/`
- `agents/` (생성된 Claude Code-facing subagent wrapper 9개)
- `opencode/` (OpenCode config hook, preference helper, 생성된 agent/command JSON)
- `hooks/`
- `scripts/`

저장소 루트는 self-hosted marketplace 역할을 유지합니다. 루트의 marketplace
manifest들은 이 디렉터리를 plugin source of truth로 가리킵니다.

OpenCode config hook은 `oh-no` primary 하나, `oh-no-<role>` subagent 9개,
OpenCode skill 11개를 로드합니다. 공개 npm 패키지는 `opencode/index.js`를
export하고 OpenCode adapter, 생성된 OpenCode skill, 패키지 문서, notice,
license만 포함하며 one-time `oh-no-harness setup` binary를 제공합니다.
`npx --yes oh-no-harness@latest setup`으로 설치·등록한 뒤 OpenCode를 완전히 종료하고
다시 시작하세요. 이어서 OpenCode에서 `/configure-subagents`를 실행하면 role별로
현재 사용 가능한 정확한 model과 model-specific variant를 선택할 수 있습니다.
읽기 전용 등록 상태 확인은 `npx --yes oh-no-harness@latest setup --check`를 사용합니다.
