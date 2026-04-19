# Stepwise Signal Model Repository

This repository currently publishes the curated MATLAB project in
`stepwise_signal_model/`.

## Current Scope

- The tracked project is `stepwise_signal_model/`.
- Root-level experiment scripts and notes are intentionally kept out of the
  repository for now.
- MATLAB runtime logs and generated local artifacts are ignored by Git.

## Repository Layout

```text
README.md
.gitignore
stepwise_signal_model/
  README.md
  setup_paths.m
  docs/
  core/
  steps/
```

## Entry Points

- Project overview: `stepwise_signal_model/README.md`
- Step mapping: `stepwise_signal_model/docs/STEP_MAP.md`
- Known issues: `stepwise_signal_model/docs/OPEN_ISSUES.md`
- MATLAB path setup: `stepwise_signal_model/setup_paths.m`

## Quick Start

Run the path setup first, then execute the demo you want to inspect.

```matlab
run('E:\matlab_code\bishe_quanxi\stepwise_signal_model\setup_paths.m')
demo_joint_2d_mtd
```

## Versioning Strategy

- `master` keeps the latest stable baseline.
- Feature or fix work should be done on separate branches and merged back after
  validation.
- The current follow-up branch for Step 5 changes is intended to isolate larger
  edits from the baseline.
