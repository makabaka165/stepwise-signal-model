# 04 Resource and Latency Plan

## 估算框架

本步骤不提供综合结果，只定义后续 Vivado/Vitis 评估时需要统计的资源和延迟维度。

| Module | Complexity Driver | Pipeline | Parallelism | Trigger Mode |
|---|---|---|---|---|
| pulse compression | samples x taps or FFT length | yes | channels / range bins | per frame |
| MTD_FFT | Doppler FFT length x range bins | yes | range bins / channels | per frame |
| CFAR | training cells + guard cells | yes | range-Doppler cells | per detection map |
| coarse_beamforming | beams x channels | yes | beams | per detection candidate |
| shared_center_column_selection | Q selected indices | yes | Q index generation | per valid center_col |
| Y_work_packing | NEL x Q x samples | yes | local columns / layers | per valid detection |
| steering_LUT | Q x NEL x grid | read pipeline | banks / grid points | on demand |
| projection_score_acceleration | dot-products x candidates | yes | candidate grid / columns | on demand |
| EVD/SVD | matrix dimension and precision | optional IP | limited | on demand |
| route decision | branch depth | no | limited | on demand |

## 可流水模块

pulse compression、MTD_FFT、CFAR、coarse_beamforming、shared_center_column_selection、Y_work_packing 和 projection_score_acceleration 都可以设计成 valid-ready 或 valid-only 流水接口。

## 可并行模块

coarse_beamforming、CFAR cell comparison、projection dot-products 和多检测单元的 Y_work packing 可以横向并行。并行度由 DSP、BRAM、AXI 带宽和时钟约束共同决定。

## 按需触发模块

projection_score_acceleration、EVD/SVD、rank1 decision、pair-local refinement 和 confidence/boundary 可按 detection candidate 触发。不是每个候选都进入最重计算。

## Lazy Cascade 的平均计算量收益

Step8.7 lazy cascade 通过先运行低成本判据，再按需触发重计算，降低平均计算量。FPGA/SoC 实现中应保持这种按需触发策略：FPGA 提供可复用高吞吐 kernel，SoC 决定是否调用更复杂的分支和浮点计算。
