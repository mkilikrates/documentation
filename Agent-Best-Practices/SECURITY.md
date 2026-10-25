# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report privately to **`<FILL IN SECURITY CONTACT / EMAIL>`** (or use GitHub's private
"Report a vulnerability" advisory feature). Include:

- A description of the issue and its impact.
- Steps to reproduce (proof of concept if possible).
- Affected versions / components.

We aim to acknowledge reports within **`<FILL IN e.g. 3 business days>`** and to provide a remediation
timeline after triage. Please give us a reasonable window to fix the issue before public disclosure.

## Supported versions

| Version | Supported |
|---|---|
| `<FILL IN>` | ✅ |
| older | ❌ |

## Our practices

Security expectations for code in this repository are defined in
[`.agent/standards/security.md`](./.agent/standards/security.md) and `AGENTS.md` §6: input
validation, secrets hygiene, least privilege, dependency pinning + scanning, and treating all
external/model content as untrusted.
