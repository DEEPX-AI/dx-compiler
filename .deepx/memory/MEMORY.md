# Memory Index — dx-compiler

> Persistent knowledge files for the dx-compiler agent-driven infrastructure.
> Read at the start of every session. Update when new patterns are discovered.

## Files

| File | Purpose | When to Read |
|---|---|---|
| `MEMORY.md` | This index | Start of every session |
| `common_pitfalls.md` | Known failure modes and fixes | Before compilation, on errors |

## Update Protocol

1. **When to update**: After encountering a new failure mode, discovering a workaround, or learning a new pattern
2. **How to update**: Add a new domain-tagged entry to `common_pitfalls.md`
3. **Format**: Follow the existing Symptom / Cause / Fix structure
4. **Review**: Check for duplicates before adding
5. **Domain tags**: Every entry must have exactly one domain tag

## Domain Tags

| Tag | Scope |
|---|---|
| `[UNIVERSAL]` | Applies to all DEEPX compilation workflows |
| `[DX_COMPILER]` | Specific to DX-COM compilation (config, CLI, API) |
| `[QUANTIZATION]` | Calibration, quantization methods, accuracy |
