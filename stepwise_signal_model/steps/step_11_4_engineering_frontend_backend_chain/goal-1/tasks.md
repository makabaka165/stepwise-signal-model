
# Goal Tasks: Step11.4 Continuous Gated Engineering Chain

## Execution Mode

本 goal 采用连续自动执行模式，但每个 task 都有决策门控。

每个 task 结束后必须：

1. 运行相关检查。
2. 生成 task report：
   step_11_4_engineering_frontend_backend_chain/goal-[num]/task_reports/taskNN_<short_name>.md
3. 更新 tasks.md。
4. 更新 records.md。
5. git status。
6. git diff --stat。
7. git commit。
8. 根据结果选择：
   - GO
   - CONTINUE_WITH_RISK
   - STOP_NEEDS_USER
   - STOP_LOGICAL_FAILURE
   - ROLLBACK
9. 若 GO 或 CONTINUE_WITH_RISK，则自动继续下一个 task。
10. 若 STOP 或 ROLLBACK，则停止。

每 3 个 task 后必须执行大型 review/debug 循环。

## Task Report Template

每个 task_report 必须包含：

```markdown
# Task NN Report: <name>

## Expected Result

## Actual Result

## Checks and Tests

## Key Outputs

## Pass/Fail Analysis

## Risks

## Decision

GO / CONTINUE_WITH_RISK / STOP_NEEDS_USER / STOP_LOGICAL_FAILURE / ROLLBACK

## Git Commit
```

## Prompt Integrity Note

The pasted prompt ends inside the Task Report Template at `## Git Commit`. It does not include `END tasks.md`, `BEGIN context.md`, or `BEGIN records.md` sections. The original prompt is preserved verbatim in `input.md`; the actionable task list below is derived from the supplied `plan.md` Stage1-4 scope so execution can continue without inventing out-of-scope work.

## Actionable Task List

- [x] Task 01: Initialize Step11.4 goal directory and management files.
- [x] Task 02: Create Step11.4 positioning README/docs and implementation skeleton without modifying Step11.1/11.2/11.3/Step9/Step10/step_11_supersolution_ml.
- [x] Task 03: Implement and run Stage1 interface contract for `frontend_out` and `backend_in`.
- [x] Review A: After Tasks 01-03, run the required broad review/debug gate.
- [x] Task 04: Implement and run Stage2 synthetic frontend coarse-angle estimation without truth-built coarse centers.
- [x] Task 05: Implement and run Stage3 frontend-to-backend chain validation against oracle backend.
- [x] Task 06: Implement and run Stage4 single-vs-pair module diagnostics.
- [ ] Review B: After Tasks 04-06, run the required broad review/debug gate.
- [ ] Task 07: Write final Step11.4 summary, run final maximum review, and decide ACCEPT/REJECT outcome.

## Current Gate

- Task 06 decision: GO
- Next task: Review B
