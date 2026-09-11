# soran-pos-backfill

Claude Code skill for automating data collection from **SORAN** (JBtoB社 ASPossible Ver.9.1) — the POS/ID-POS analysis system used by ツルハグループ (Tsuruha Group drugstores, contract org 00538 / サン・スマイル, ベーシックプラン).

## What's here

- `SKILL.md` — the skill itself. Runs exactly one 31-day backfill window of the "日別店別品名別ダウンロード" (daily store×SKU POS download) screen per invocation, verifies it, compresses it, logs it, and stops (designed to be re-invoked repeatedly via `/loop`, not looped internally — see the skill for why).
- `reference/soran_tools.ps1` — low-level PowerShell helpers for driving the `visual.exe` desktop app: coordinate clicks with human-like jitter/timing, window/focus helpers, UI Automation tree walking, screenshot capture. No credentials are stored anywhere in this script.
- `reference/audit_report.md` — 2026-08-26 hands-on investigation of what the Basic-plan contract can and cannot extract from SORAN (per-screen capability, column schemas, limits, contract questions to ask the vendor).
- `reference/download_catalog.csv` — machine-readable per-screen catalog (navigation path, filters, output format, columns, automation difficulty) for every menu investigated, including screens not yet turned into a skill (store/product master, プラノグラマー連携, 在庫検索, メイン分析, and several unexplored 拡張分析 menus).
- `reference/schema_catalog.csv` — column-level schema detail backing the audit report.
- `reference/collection_plan.md` — the original collection plan (phases, folder layout, safety rules, standing-operation cadence for masters/inventory/planogrammer/main-analysis) that this skill implements Phase 2 of.

## Status as of 2026-09-11

The daily_store_sku backfill this skill automates **already ran to completion**: 63/63 windows, 2021-05-16 through 2026-08-25, per the original `manifests/collection_log.csv` (not included here — see below). The other flows described in `reference/collection_plan.md` (store/product master, プラノグラマー連携, 在庫検索, メイン分析標準ビュー) were scoped but not all turned into standalone skills yet.

## What's intentionally NOT in this repo

The ~34GB of collected raw POS/master data (`jbtob_collection_20260827/raw/...`) is **not included** — it's client POS data under the JBtoB/Tsuruha contract and doesn't belong in a code repository. It was left on the original machine; if that machine is being wiped, make sure the raw data is copied somewhere durable (shared drive, GCS, etc.) separately before that happens.

## Reusing this on a new machine

Screen coordinates in `SKILL.md` and any future extensions are tied to the exact screen resolution/DPI/window position of the machine they were recorded on — expect to recalibrate them (via screenshot + `Get-UITree` from `soran_tools.ps1`) on a new machine rather than trusting the numbers verbatim. The procedural logic (navigation order, dialog handling, retry/stop rules, safety rules) carries over as-is.
