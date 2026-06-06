# Stage4 Single-vs-Pair Module Diagnostics Plan

## Goal

Show that ordinary single-target cases should not be forced into pair2d by
default, while pair2d remains useful as an unresolved-cluster enhanced mode.

## Planned Outputs

- `single_target_false_split_rate`
- `pair_target_success_rate`
- `recommended_trigger_policy_text`

## Interpretation Boundary

This stage may recommend trigger logic, but it must not claim complete
automatic target-count selection.

