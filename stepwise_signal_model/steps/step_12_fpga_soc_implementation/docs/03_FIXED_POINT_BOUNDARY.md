# 03 Fixed-Point Boundary

## Step8.9 结论整理

Step8.9 和 Step10 evidence 表明当前 shared-center 主线的 fixed-point not closed。已有证据文件 `steps/step_10_final_thesis_route/evidence/step89_hardware_boundary_keypoints.csv` 给出：

- `fixed_point_pass_flag = 0`
- `recommended_fixed_point_format = not_recommended`
- `fixed_point_blocker_if_any = quantization_not_closed`
- `proceed_to_fpga_kernel_design_flag = 0`

这些结论说明，当前不能把 Step8.7 verified lazy cascade 直接声明为完整纯 FPGA 定点后端。

## 敏感源

Step8.9 系列诊断指出，steering/template/cache 系数量化较敏感。EVD/SVD、rank1 route decision、candidate tie、confidence/boundary 判断也容易受数值扰动影响。

## 工程边界

第一版工程实现采用 FPGA/SoC 协同：

- FPGA：前端、规则流式处理、shared-center 抽取、Y_work packing、可选 projection score 加速。
- SoC/CPU：EVD/SVD、Step8.7 lazy cascade route decision、rank1 / pair-local 判断、confidence/boundary 和日志。

本步骤不新增算法实验，不伪造固定点闭合结果，只引用已有 Step8.9 / Step10 evidence。
