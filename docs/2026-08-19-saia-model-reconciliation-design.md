# SAIA Model Capability Reconciliation — Design

Date: 2026-08-19
Status: Approved (design sections reviewed in conversation)
Scope: omp-saia-plugin

## Problem

Keeping SAIA models and their real capabilities up to date is manual. The model *list* is already auto-discovered from `/v1/models`, but:

- **Reasoning** (thinking) detection relies on a hand-maintained override set, built by manually probing each model with `reasoning_effort`.
- **Context windows** live in a static table (`constants.ts`) copied by hand from SAIA's docs page.
- **Vision** is automatic (API `input` modalities).
- SAIA rotates date-stamped model variants (e.g. `deepseek-v4-flash-0731`), which previously broke exact-match lookups entirely (fixed separately via `baseModelId`).

Goal: model stats are always as up to date as possible, reconciled automatically in the background / at startup, **without the user noticing or being impacted**.

## Non-goals

- **Shortening omp's 24h discovery cache** — investigated (2026-08-19): the model-cache TTL is a hardcoded `86400000` ms literal at the readModelCache call sites in the runtime bundle (`dist/cli.js`); the catalog's `readModelCache(providerId, ttlMs, …)` takes the TTL as a parameter with no env var, config key, or extension API controlling it (`omp config list` has no discovery-TTL knob; `providers.cacheRetention` is prompt-response caching, unrelated). One special provider path uses a 2h TTL (`7200000`), confirming the value is per-call-site. Shortening the cache requires an upstream omp change. The reconciler's store mitigates: every omp re-discovery (24h tick, `omp models`, `omp models refresh`, fresh start) reads the fresh store.
- **Detached daemon** — reconciliation runs inside omp sessions (startup + timer). A laptop that never runs omp stays stale until the next session; acceptable.
- **Per-effort-level verification** — probes detect reasoning *presence* only. omp's runtime clamps unsupported effort levels and has a `reasoning_effort` 400 fallback that learns allowed values; per-level probing is redundant.
- **maxTokens auto-derivation** — not exposed by the API; stays a static default.

## Architecture

One new module, minimal changes to existing files:

- **`reconciler.ts`** (new) — store I/O, reconcile cycle, reasoning probe, docs scrape. Exports pure helpers (probe parsing, scrape parsing, merge precedence, config parsing) testable without network.
- **`discovery.ts`** — `buildModelDefs`/discovery callback gains a store-merge step: store values win over static tables when present; otherwise behavior is unchanged.
- **`index.ts`** — starts the reconciler deferred (fire-and-forget, never awaited); registers the `/saia-refresh` slash command; passes a shared store handle to discovery.
- **`constants.ts`** — timing defaults (overridable via env, see below).
- **`types.ts`** — store schema.

### Store schema

JSON at `SAIA_RECONCILE_STORE_PATH` (default `~/.omp/agent/saia-models.json`), atomic writes (tmp + rename):

```ts
interface ModelStore {
  version: 1;
  updatedAt: string;                 // last successful cycle, ISO
  models: Record<string, {
    reasoning?: boolean;             // absent = unknown
    vision?: boolean;
    contextWindow?: number;          // absent = unknown
    maxTokens?: number;
    probedAt?: string;               // weekly re-verify cadence
    probeFailures?: number;          // backoff for failing models
    contextScrapedAt?: string;
  }>;
}
```

Keys are exact served model ids; base-id stripping (`baseModelId`) applies on lookup.

Corrupt store at read: renamed aside (`.corrupt-<timestamp>`), treated as empty; discovery falls back to static tables.

### Configuration (env vars, all with defaults)

| Variable | Default | Meaning |
|---|---|---|
| `SAIA_RECONCILE_STARTUP_DELAY_MS` | `5000` | defer reconcile after session start |
| `SAIA_RECONCILE_INTERVAL_MS` | `21600000` (6h) | background cycle |
| `SAIA_RECONCILE_STALE_AFTER_MS` | `43200000` (12h) | catch-up reconcile at startup if store older |
| `SAIA_RECONCILE_PROBES_PER_CYCLE` | `2` | probe budget per cycle |
| `SAIA_RECONCILE_PROBE_TIMEOUT_MS` | `20000` | per-probe timeout |
| `SAIA_RECONCILE_REVERIFY_MS` | `604800000` (7d) | per-model re-verify cadence |
| `SAIA_RECONCILE_SCRAPE_INTERVAL_MS` | `604800000` (7d) | docs scrape cadence |
| `SAIA_RECONCILE_SCRAPE_TIMEOUT_MS` | `15000` | scrape fetch timeout |
| `SAIA_RECONCILE_STORE_PATH` | `~/.omp/agent/saia-models.json` | store location |
| `SAIA_RECONCILE_DISABLED` | unset | kill switch; any truthy value disables reconcile |

Invalid env values (non-numeric, ≤0 where meaningless) fall back to defaults. Documented in README and the bundled skill.

## Reconcile cycle

Single-flight: one cycle at a time (timer + startup catch-up cannot overlap).

```
reconcile():
  list = fetchModels(apiKey)         # POST /v1/models; failure → abort cycle, keep store
  for each ready model:
    entry = store.models[id] ?? {}
    entry.vision = input.includes("image")            # authoritative from API
    reasoning:
      output.includes("thought")     → true           # authoritative
      else override/base-id match    → true           # authoritative
      else unknown + due (never probed or REVERIFY elapsed)
                                     → probe (≤ PROBES_PER_CYCLE, PROBE_TIMEOUT_MS)
        probe success → set reasoning; failure → keep last-known, probeFailures++
        (≥3 consecutive failures → re-verify cadence drops to weekly)
    contextWindow: scraped value (fresh) → static table → last-known → default 128K
  store.updatedAt = now; persist atomically
  schedule next cycle in INTERVAL
```

**Reasoning probe** — `POST /chat/completions` with `{ messages: [{role:"user", content:"Say OK"}], reasoning_effort: "high", max_tokens: 1, stream: true }`; any `delta.reasoning*` content → reasoning `true`, else `false`. ~2 tokens per probe.

**Context scrape** — `GET` SAIA docs page (same source the static table was copied from); parse per-model context lengths. Parse failure / page change → static table. Scraped value preferred over static table when fresh.

## Discovery integration

`fetchDynamicModels`: fetch list → load store → merge → build defs. Never awaits the reconciler; reads whatever the store holds.

| Field | Precedence |
|---|---|
| `reasoning` | store (known) → API `output` has `"thought"` → override/base-id match → `false` |
| `vision` | API `input` (always present) |
| `contextWindow` | store (scraped/last-known) → static table (exact → base-id) → 128K default |
| `maxTokens` | store (currently never set) → 32K default |

## Manual trigger

`/saia-refresh` slash command (`pi.registerCommand`): runs a reconcile immediately (awaited by the command), reports a one-line summary via `ctx.ui.notify` (models seen, probes run, failures). Store updates land; `omp models refresh` then surfaces them immediately (extension API has no direct registry nudge).

## Error handling & invisibility

- Every failure degrades silently to last-known-good or the static fallback; logged at `warn` via `pi.logger` (existing pattern).
- No key → skip reconcile (discovery already returns `[]` today).
- Reconcile is detached: deferred start, async cycle, never awaited by discovery. Only `/saia-refresh` awaits it (user-initiated).
- Managed timer lifecycle, auto-cleared on session shutdown (same `ctx.setInterval` pattern as the saia-quota extension).
- Probe backoff prevents hammering permanently failing models (e.g. medgemma currently 500s).
- Quota: ~2-token probes, ≤2 per cycle, staggered; negligible.

## Testing

Network-free unit tests (existing `stubFetch` pattern, bun:test), new `reconciler.test.ts`:

- Probe stream → reasoning boolean (reasoning delta, text-only, empty, timeout/error)
- Scrape HTML fixture → context-window map (table parse, missing rows, malformed page)
- Merge precedence table (store vs API vs override vs default, incl. base-id variant lookup)
- Store round-trip + corrupt-file fallback
- Env config parsing (defaults, overrides, invalid → defaults)

Existing suite untouched and still passing.

## Files touched

- `extensions/reconciler.ts` (new)
- `extensions/discovery.ts` (merge step)
- `extensions/index.ts` (start reconciler, register command)
- `extensions/constants.ts` (timing defaults)
- `extensions/types.ts` (store schema)
- `test/reconciler.test.ts` (new)
- `README.md`, `skills/saia-models/SKILL.md` (env vars + command docs)
- `CHANGELOG.md` (entry)
