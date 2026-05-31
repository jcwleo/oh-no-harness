# Oh No Harness Plugin Package

이 디렉터리는 `oh-no-harness` 플러그인의 source package입니다.

사용자를 위한 canonical 문서는 저장소 루트에 있습니다.

- [README](../../README.md)
- [한국어 README](../../README.ko.md)

플러그인 개발 규칙은 이 패키지 옆 문서에 있습니다.

- [Contributing](CONTRIBUTING.md)

이 패키지는 Claude Code와 Codex가 사용하는 플러그인 manifest, runtime
surface, 유지보수 참고 문서를 담고 있습니다.

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `skills/` (Codex-facing wrapper)
- `skills-claude/` (Claude Code-facing wrapper)
- `docs/skill-core/` (공용 workflow core)
- `docs/providers/` (platform 문서를 유지보수하기 위한 회사별 prompt guide 참고 문서, 실행 경로 아님)
- `commands/`
- `agents/`
- `hooks/`
- `scripts/`

저장소 루트는 self-hosted marketplace 역할을 유지합니다. 루트의 marketplace
manifest들은 이 디렉터리를 plugin source of truth로 가리킵니다.
