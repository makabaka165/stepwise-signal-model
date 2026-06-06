
# Goal Plan: Step11.4 Engineering Frontend-Backend Chain with Continuous Gated Execution

## 0. Directory and Input Preservation Rule

This goal is scoped inside Step11.4.

The Step11.4 main directory must be created first:

stepwise_signal_model/steps/step_11_4_engineering_frontend_backend_chain/

Then create the goal directory inside it:

stepwise_signal_model/steps/step_11_4_engineering_frontend_backend_chain/goal-[num]/

The goal management files must live inside that goal directory:

- input.md
- plan.md
- tasks.md
- context.md
- records.md
- task_reports/

input.md is not a summary or plan.
It must preserve the full original `/goal` prompt verbatim.

Therefore:

- Do not rewrite input.md into a task summary.
- Do not normalize, translate, or compress input.md.
- Do not move plan content into input.md unless it is part of the raw prompt.
- Do not move tasks content into input.md unless it is part of the raw prompt.
- plan.md is the analytical document derived from input.md.
- tasks.md is the actionable task decomposition derived from plan.md.
- context.md protects against context compaction.
- records.md records expected/actual/deviation/decision.

## 1. Goal Summary

本 goal 的目标是在当前项目中新增：

stepwise_signal_model/steps/step_11_4_engineering_frontend_backend_chain/

用于从工程角度尝试串联：

前端粗检测 / 粗测角 / 二维波束扫描
-> frontend_out
-> backend_in
-> Step11.2 推荐 W = greedy_combined_B7
-> Step11.3 推荐 degree-based coarse-to-fine controlled pair2d beamspace ML
-> 局部双目标增强测角输出

本 goal 采用“连续执行 + 每 task 决策门控”的模式。

也就是说：

1. 每次仍然只执行一个 task。
2. 每个 task 完成后必须：
   - 运行检查；
   - 写 task 结果分析文档；
   - 更新 tasks.md；
   - 更新 records.md；
   - 提交 git；
   - 根据 task 结果做 GO / CONTINUE_WITH_RISK / STOP / ROLLBACK 决策。
3. 若 task 符合预期，则自动继续下一个 task。
4. 若 task 不符合预期且逻辑上已经阻断后续，则停止。
5. 若 task 不符合预期但只是暴露当前模块问题，不影响后续诊断，则记录清楚并继续。
6. 每 3 个 task 后执行大型全面 review/debug 循环。
7. 全部 task 完成后执行最终最大 review。

## 2. Existing Algorithm Context

### 2.1 Step11.1

Step11.1 已完成 controlled pair2d beamspace ML 后端验证。

核心模型：

Y = A_cyl(Theta) S + N  
Z = W'Y  
G(Theta) = W'A_cyl(Theta)  
J(Theta) = trace(P_G Z Z')  
P_G = G(G'G)^(-1)G'

主算法：

controlled pair2d beamspace ML

它不是 AP，不是 full4D，不是阵元域 ML。

### 2.2 Step11.2

Step11.2 已完成 W 选择。

推荐：

W = greedy_combined_B7

含义：

从已有二维波束池中选择 7 个低冗余、低相关、条件数稳定的任务相关波束，作为 Step11 后端的 beamspace transform。

### 2.3 Step11.3

Step11.3 已完成搜索加速。

推荐：

degree-based coarse-to-fine controlled pair2d search

配置：

- topK = 3
- coarse_az_step = 0.16 deg
- coarse_el_step = 0.24 deg
- coarse_el_sep_deg_list = [0, 0.36, 0.72]
- fine_az_step = 0.08 deg
- fine_el_step = 0.12 deg
- local_az_half_width = 0.32 deg
- local_el_center_half_width = 0.48 deg
- fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72]

关键结果：

- coarse_to_fine_success = 1
- coarse_to_fine_rmse = 0.0765589261214
- complexity_reduction_ratio = 6.86054096932
- topK_miss_rate = 0
- boundary_hit_rate = 0
- search_acceleration_pass_flag = 1

前端粗角偏差鲁棒性：

- zero_bias_success = 1
- max_bias_success_drop = 0.06
- max_bias_topK_miss_rate = 0
- max_bias_boundary_hit_rate = 0
- valid_bias_range = az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]
- frontend_prior_robustness_pass_flag = 1

## 3. Engineering Problem

前端和后端不是同一个层级。

### 3.1 Frontend Layer

前端 CFAR / 三波束 / 二维波束粗测角通常输出：

- 一个检测单元；
- 一个主导粗峰；
- 一个 coarse_az / coarse_el；
- 一个 center beam；
- 局部波束能量；
- 一个粗搜索窗口；
- 可能的 SNR / spread / cluster 指标。

前端输出一个 coarse peak 不代表物理上一定只有一个目标，也不代表已经检测出两个目标。

### 3.2 Backend Layer

Step11 后端是局部未分辨双目标增强模式。

它假设：

一个 frontend coarse peak 内部可能包含两个角度接近的未分辨目标。

后端处理：

- 用 frontend coarse center 确定搜索窗口；
- 用 greedy_combined_B7 构造 W；
- 用 Z = W'Y 构造 beamspace snapshots；
- 用 controlled pair2d beamspace ML 做局部双目标估计；
- 用 Step11.3 coarse-to-fine 搜索加速。

### 3.3 Unifying Interpretation

正确统一方式：

前端检测到一个 local coarse peak；Step11 后端研究这个 coarse peak 内部的 unresolved pair enhancement。

错误表述：

1. 前端已经检测出两个目标。
2. CFAR 必须完成单双目标分类。
3. 前端单峰就是物理单目标。
4. 所有单目标都必须进入 pair2d。
5. Step11 后端替代 CFAR。
6. 完整自动目标数判断已经解决。

## 4. Goal Scope

### 4.1 In Scope

1. 新建 Step11.4 目录。
2. 在 Step11.4 内部创建 goal-[num] 管理目录。
3. 定义 frontend_out 和 backend_in。
4. 实现 synthetic frontend beam scan。
5. 实现 coarse angle 估计。
6. 实现 frontend_out -> backend_in。
7. 调用 Step11.2 / Step11.3 后端。
8. 比较 oracle backend 和 synthetic frontend backend。
9. 诊断普通单目标是否应该触发 pair2d。
10. 若串联失败，输出 failure_reason 和模块化建议。
11. 每个 task 产出结果文档和分析文档。

### 4.2 Out of Scope

1. 不做完整真实 CFAR/MTD 工程闭环。
2. 不做最终自动单双目标模型选择。
3. 不做 AP。
4. 不做 full4D。
5. 不做阵元域 ML。
6. 不重写 Step11.1/11.2/11.3。
7. 不修改 Step9/Step10/step_11_supersolution_ml。
8. 不宣称完整工程闭环完成。
9. 不隐藏失败。

## 5. Continuous Gated Execution Rules

每个 task 完成后必须执行以下流程。

### 5.1 Required End-of-Task Artifacts

每个 task 必须生成或更新：

1. tasks.md 中该 task 的完成记录；
2. records.md 中该 task 的预期/实际/对齐/成因/决策；
3. goal-[num]/task_reports/taskNN_<short_name>.md；
4. 如果是 Step11.4 的 stage task，还必须生成对应 stage 结果：
   - CSV；
   - MAT；
   - log；
   - keypoints；
   - README 状态；
   - 必要 PNG。

### 5.2 Decision Types

#### GO

当前 task 符合预期，可自动继续下一个 task。

#### CONTINUE_WITH_RISK

当前 task 未完全达标，但不阻断后续，必须继续验证。

适用例子：

- Stage2 frontend coarse angle 误差偏大，但这本身就是要通过 Stage3 判断是否影响后端；
- 某个 coarse method 不好，但还有其他 method 可用；
- single target false split 高，但这只说明普通单目标不应默认触发 pair2d，不阻断 pair mode 验证。

#### STOP_NEEDS_USER

当前 task 不通过且后续需要用户决策。

#### STOP_LOGICAL_FAILURE

当前结果说明 goal 的核心假设在当前条件下不成立，继续执行没有意义。

#### ROLLBACK

当前实现错误或破坏已有项目。

## 6. Rollback Strategy

每个 task 完成后必须 commit。

如果需要回滚：

1. 查看 git status。
2. 查看 git diff --stat。
3. 确认本 task commit。
4. 使用 git revert 或 reset 回滚当前 task。
5. 在 records.md 记录 ROLLBACK。
6. 停止执行。

## 7. Review Strategy

每 3 个 task 后执行大型 review/debug 循环。

Review 内容：

1. 是否违反禁止修改范围；
2. 是否出现真值泄漏；
3. 是否前后端层级表述错误；
4. 是否所有 stage 可复现；
5. 是否结果文件完整；
6. 是否 README 和 docs 过度宣称；
7. 是否需要调整后续 task。

## 8. Proposed Step11.4 Directory Structure

step_11_4_engineering_frontend_backend_chain/
  README.md
  goal-[num]/
    input.md
    plan.md
    tasks.md
    context.md
    records.md
    task_reports/
  docs/
    00_STEP11_4_POSITIONING.md
    01_FRONTEND_BACKEND_INTERFACE_THEORY.md
    02_STAGE1_INTERFACE_CONTRACT_PLAN.md
    03_STAGE2_SYNTHETIC_FRONTEND_COARSE_ANGLE_PLAN.md
    04_STAGE3_FRONTEND_TO_BACKEND_CHAIN_VALIDATION_PLAN.md
    05_STAGE4_SINGLE_VS_PAIR_MODULE_DIAGNOSTICS_PLAN.md
    06_FINAL_STEP11_4_ENGINEERING_CHAIN_SUMMARY.md
  common/
    make_frontend_out_struct.m
    make_backend_in_from_frontend_out.m
    build_frontend_beam_pool_from_existing_layout.m
    run_synthetic_frontend_beam_scan.m
    estimate_coarse_angle_from_frontend_beams.m
    compute_frontend_cluster_indicators.m
    build_step11_backend_config_from_frontend.m
    run_step11_pair2d_backend_from_interface.m
    evaluate_frontend_backend_chain_metrics.m
    summarize_frontend_backend_chain_keypoints.m
    plot_frontend_backend_chain_results.m
    append_log_local.m
  stage1_interface_contract/
    run_stage1_interface_contract.m
  stage2_synthetic_frontend_coarse_angle/
    run_stage2_synthetic_frontend_coarse_angle.m
  stage3_frontend_to_backend_chain_validation/
    run_stage3_frontend_to_backend_chain_validation.m
  stage4_single_vs_pair_module_diagnostics/
    run_stage4_single_vs_pair_module_diagnostics.m
  results_step11_4_stage1_interface_contract/
    .gitkeep
  results_step11_4_stage2_synthetic_frontend_coarse_angle/
    .gitkeep
  results_step11_4_stage3_frontend_to_backend_chain_validation/
    .gitkeep
  results_step11_4_stage4_single_vs_pair_module_diagnostics/
    .gitkeep

## 9. Stage Plans

### Stage1: Interface Contract

Goal:

定义 frontend_out 和 backend_in。

Pass:

- frontend_out_fields_ok = 1
- backend_in_fields_ok = 1
- interface_contract_pass_flag = 1

### Stage2: Synthetic Frontend Coarse Angle

Goal:

用合成二维前端波束扫描估计 coarse angle，不用真值中心。

Methods:

- peak
- centroid_top9
- centroid_threshold

Metrics:

- coarse_az_error
- coarse_el_error
- within_pm02deg_rate
- beam_spread_indicator
- cluster_indicator

### Stage3: Frontend-to-Backend Chain

Goal:

用 synthetic frontend coarse center 驱动 Step11 后端，并与 oracle backend 对比。

Pass:

- synthetic success >= 0.85 * oracle success
- topK_miss_rate <= 0.1
- boundary_hit_rate <= 0.2

### Stage4: Single vs Pair Module Diagnostics

Goal:

证明普通单目标不应默认强制进入 pair2d，pair2d 是 unresolved cluster enhanced mode。

Outputs:

- single_target_false_split_rate
- pair_target_success_rate
- recommended_trigger_policy_text

## 10. Final Deliverable

最终结果不要求一定完整工程闭环成功。

最终必须回答：

1. Step11.4 是否能接口级串联？
2. 如果不能，瓶颈在哪里？
3. 前端 coarse angle 是否足够进入 Step11 后端？
4. synthetic frontend backend 与 oracle backend 的差距？
5. 普通单目标是否应默认触发 pair2d？
6. 工程实现建议是完整串联，还是模块化继续验证？
7. 小论文算法路线和工程路线如何分开写？
