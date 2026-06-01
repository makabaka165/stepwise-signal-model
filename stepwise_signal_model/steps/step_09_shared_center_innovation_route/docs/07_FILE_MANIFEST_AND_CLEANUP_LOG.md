# 文件清单与清理记录

本次整理采用“新增 Step 09 主线目录、历史目录保留为证据来源”的方式执行。已有 8.x 目录中存在用户未提交改动，因此不对历史文件做物理删除；删除动作仅表示从 Step 09 主线说明和最终算法流程中删除。

## keep

| 路径 | 处理 | 理由 |
|---|---|---|
| `README.md` | keep | Step 09 主线说明 |
| `run_final_shared_center_demo.m` | keep | 最终 demo 入口 |
| `run_final_shared_center_validation.m` | keep | 最终 validation 入口 |
| `main/shared_center_enhanced_doa.m` | keep | 主算法入口 |
| `main/shared_center_select_subarray.m` | keep | shared-center 65 列选阵 |
| `main/build_y_work_from_frontend.m` | keep | 前端检测单元到 Y_work |
| `main/local_cylindrical_music_test.m` | keep | 局部圆柱阵 MUSIC 判别 |
| `main/coherent_rank1_refocus_fallback.m` | keep | common-el rank1 fallback |
| `main/local_2d_pair_refinement.m` | keep | 二维失配局部 refinement |
| `main/confidence_boundary_rejector.m` | keep | 低置信/边界拒判 |
| `results/final_keypoints.csv` | keep | 最终关键指标 |
| `results/final_summary.csv` | keep | demo 输出摘要 |
| `results/final_route_flowchart.png` | keep | 主线流程图 |
| `results/final_frontend_interface.png` | keep | 前端接口图 |
| `results/final_scenario_examples.png` | keep | 场景示例图 |

## rewrite

| 来源 | 新位置 | 处理 |
|---|---|---|
| Step 8.11 final summary 文档口径 | `README.md`, `docs/00_ROUTE_POSITIONING.md` | rewrite 为 Step 09 论文/答辩主线 |
| Step 8.7/8.8/8.9/8.10 结果表 | `docs/03_EXPERIMENT_EVIDENCE.md`, `results/final_keypoints.csv` | rewrite 为最终证据链 |
| Step 8.8 接口说明 | `docs/02_FRONTEND_INTERFACE.md` | rewrite 为前端状态机 |
| Step 8.9 硬件结论 | `docs/04_HARDWARE_FPGA_SOC_BOUNDARY.md` | rewrite 为硬件边界 |

## archive

| 内容 | archive 定位 |
|---|---|
| Step 8.7 lazy cascade、common-el refocus、pair-local refinement | `archive/step87_original_notes/` |
| Step 8.8 frontend closure 和 Step 8.8B de-rotation | `archive/step88_interface_notes/` |
| Step 8.9 / 8.9B / 8.9C fixed-point diagnostics | `archive/step89_fixed_point_boundary/` |
| Step 8.10 unified model selection | `archive/step810_unified_negative/` |

## delete from mainline

| 内容 | 处理 | 理由 |
|---|---|---|
| dual-center | delete from mainline | 当前主线只处理 single coarse peak / unresolved local cluster |
| complex-gain / V2 | delete from mainline | 未来一般相干源扩展，不进入最终算法 |
| weak target solving | delete from mainline | 只做 low-confidence / boundary protection |
| near anti-phase solving | delete from mainline | 只做 boundary_unreliable / low-confidence |
| Step 8.10 unified model selection | delete from mainline | false-high 过高且 success 明显低于 cascade |
| Step 8.9 fixed-point hardening | delete from mainline | 定点未闭合，只作为硬件边界证据 |
| Step 8.8B Doppler de-rotation | delete from mainline | 三种模式输出一致，默认不启用 |

## physical delete

本次未物理删除历史文件。原因：现有工程已有未提交改动，且历史结果仍是 Step 09 文档证据来源。物理清理应在论文主线冻结后另开一次只处理 archive/obsolete artifacts 的操作。
