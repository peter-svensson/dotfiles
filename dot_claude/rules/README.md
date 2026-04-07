# Rules

## Structure

```
rules/
├── common/          # Language-agnostic (git workflow)
│   └── git-workflow.md
├── typescript/      # TypeScript/JavaScript specific
│   ├── coding-style.md
│   └── patterns.md
└── golang/          # Go specific
    ├── coding-style.md
    ├── testing.md
    └── patterns.md
```

- **common/** contains workflow rules that apply across all languages.
- **Language directories** contain language-specific coding style, patterns, and testing rules.
- **Agents** (`agents/` directory) handle review and enforcement (code-reviewer, security-reviewer, etc.).
- **Skills** (`skills/` directory) provide deep reference material for specific tasks (golang-patterns, postgres-patterns, etc.).

Rules tell you *what* to do; skills tell you *how* to do it; agents enforce both.
