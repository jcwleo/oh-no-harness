# Oh No Harness Marketplace

이 저장소는 Oh No Harness 자체가 아니라, Oh No Harness를 배포하기 위한
self-hosted marketplace wrapper입니다.

실제 plugin source of truth는 아래 디렉터리입니다.

```text
plugins/oh-no-harness/
```

루트의 marketplace manifest는 이 plugin 디렉터리를 가리킵니다.

- `.claude-plugin/marketplace.json` - Claude Code
- `.agents/plugins/marketplace.json` - Codex

설치 명령은 그대로입니다.

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness

codex plugin marketplace add jcwleo/oh-no-harness
```

사용법, 개발, release 절차는 plugin 문서를 기준으로 보세요.

- [Plugin README](plugins/oh-no-harness/README.md)
- [Contributing](plugins/oh-no-harness/CONTRIBUTING.md)
