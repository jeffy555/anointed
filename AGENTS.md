# Anointed — mobile-app spec pipeline

This project is built through a staged pipeline. Cursor agents and skills replace the former Claude Code `.claude/` setup.

## How to run it

| Step | Invoke | Writes | Notes |
|------|--------|--------|-------|
| 1. Requirements | `/requirements-interview` | `requirements.json` | Live interview in this chat. Do not delegate. |
| 2. Architecture | `/architecture-agent` | `architecture.html`, `product-overview.pdf` | Autonomous subagent. |
| 3. UX design | `/ux-design-agent` | `design-spec.md` | After architecture. |
| 4. Analytics + QA | `/analytics-agent` and `/qa-test-plan-agent` | `analytics-spec.md`, `test-plan.md` | Can run in parallel after `design-spec.md`. |
| 5. Approval | `/approve-gate` | `feature-plan.md`, `approval.json` | Live human checkpoint. Required before any app code. |
| 6. Scaffold | `/code-generator-agent` | app scaffold, `implementation-status.md` | Refuses without `approval.json`. |
| 7. Audit | `/security-compliance-agent` and `/flow-validation-agent` | `compliance-report.md`, `flow-validation.md` | Parallel. Report only — they do not fix. |
| 8. Build | `/implementation-agent` | remaining feature logic | Runs the full `buildOrder` unless you name one slice. |

You can also ask in natural language ("start the requirements interview", "run architecture", "approve the specs"). The parent agent should follow the same order.

## Hard rules

- Nothing after step 5 may run until `/approve-gate` has written `approval.json` with `"approved": true`.
- Do not generate CI/CD or deployment config.
- Spec agents (steps 2–4) produce documents only — no app code.
- Code Generator writes **real working code** by default. Stubs are allowed only with an explicit `HANDOFF(Implementation Agent)` marker for money/legal, multi-party state machines, or LLM-split decisions.
- Security and Flow Validation audit; Implementation fixes.

## Artifact contract

Downstream stages read these keys and filenames by name. Do not rename them.

- `requirements.json` — schema owned by `/requirements-interview`
- `architecture.html`, `product-overview.pdf`
- `design-spec.md`, `analytics-spec.md`, `test-plan.md`
- `feature-plan.md`, `approval.json`
- `compliance-report.md`, `flow-validation.md`
- `implementation-status.md`

## Layout

```
.cursor/agents/     custom subagents (isolated context)
.cursor/skills/     live slash workflows (interview, approval gate)
.cursor/rules/      always-on pipeline orchestration
```

The original `.claude/` copies are unused by Cursor once `.cursor/` is present (project `.cursor/agents/` takes precedence over `.claude/agents/`).
