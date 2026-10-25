# Requirements

> **This is the single living requirements document for the whole product** (see
> [`AGENTS.md`](../../AGENTS.md) §9). It is **current-state**, not a changelog: when a requirement
> changes, edit it in place — never append "Requirement N: like M but better". Do not create a new
> spec folder per feature; everything integrates here.
>
> Requirements use **EARS** phrasing so they are testable:
> - Ubiquitous: `THE <system> SHALL <response>.`
> - Event: `WHEN <trigger>, THE <system> SHALL <response>.`
> - State: `WHILE <state>, THE <system> SHALL <response>.`
> - Option: `WHERE <feature is present>, THE <system> SHALL <response>.`
> - Unwanted: `IF <condition>, THEN THE <system> SHALL <response>.`

## Introduction

`<FILL IN: one or two paragraphs describing what this product is and its defining constraints.>`

## Glossary

- **`<Term>`**: `<definition>` — define every proper noun used below so requirements stay precise.

## Requirements

### Requirement 1: `<Title>`

**User Story:** As a `<role>`, I want `<capability>`, so that `<benefit>`.

#### Acceptance Criteria

1. THE `<system>` SHALL `<response>`.
2. WHEN `<trigger>`, THE `<system>` SHALL `<response>`.
3. IF `<error condition>`, THEN THE `<system>` SHALL `<graceful response>`.

<!-- Add requirements by editing existing ones where they overlap, and only appending genuinely new
     capabilities. Before adding, read the related existing requirements (AGENTS.md §9 conflict
     detection) and reconcile rather than duplicate. -->
