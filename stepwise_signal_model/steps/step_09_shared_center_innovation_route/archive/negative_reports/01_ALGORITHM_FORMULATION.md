# 算法公式与伪代码

## 信号模型

前端给出检测单元 `rangeIdx`、`dopplerIdx`、粗方位 `coarseAz`、粗俯仰 `coarseEl` 和 `frontend_state`。圆柱阵第 `k` 列、第 `m` 层阵元坐标记为

```text
r_{k,m} = [X_{k,m}, Y_{k,m}, Z_{k,m}]^T
```

局部窄带快拍可写为

```text
y_p = sum_l alpha_{l,p} a(az_l, el_l) + n_p
```

其中 `a(az, el)` 是圆柱阵局部 steering vector。

## shared-center 选阵公式

给定全阵列角 `phiCol(k)`：

```text
selectedCenterColumn = argmin_k |wrap180(phiCol(k) - coarseAz)|
selectedWorkColumns = selectedCenterColumn + [-32, ..., 0, ..., +32]
```

列索引用圆周取模，默认 `Q_work_columns = 65`。

## Y_work 构造

从 raw cube 中抽取 shared-center 工作子阵：

```text
Y_work = raw_cube(selectedWorkColumns, :, rangeIdx, dopplerIdx, :)
Y_work in C^(65 x 32 x Np)
```

默认 `derotation_mode = none`。Doppler de-rotation 只作为工程可选字段，不进入主算法图。

## 局部圆柱阵 steering

采用方向向量

```text
u(az, el) = [cos(el)cos(az), cos(el)sin(az), sin(el)]^T
```

则

```text
a_{k,m}(az, el) = exp(j * 2*pi/lambda * r_{k,m}^T u(az, el))
```

所有 steering vector 在谱计算前做列归一化。

## 局部 MUSIC 谱

把 `Y_work` 展开为阵元 x 快拍矩阵 `Y`，估计协方差

```text
R = Y Y^H / Np
```

取噪声子空间 `E_n` 后，在 common-elevation 网格上计算

```text
P_MUSIC(az) = 1 / ||E_n^H a(az, coarseEl)||_2^2
```

若双峰稳定、间隔和峰值比满足阈值，则直接输出 MUSIC 双峰。

## 相干秩亏时的 rank1 fallback

当局部 MUSIC 单峰或双峰合并，且特征值显示 rank1-like 协方差时，取主奇异向量 `u1`，在 common-el pair 候选上计算投影得分：

```text
A_pair = [a(az1, coarseEl), a(az2, coarseEl)]
score(az1, az2) = ||Proj(A_pair) u1||_2^2 / ||u1||_2^2
```

仅在前端仍认为该单元是未分辨局部簇、且得分和 margin 达标时输出；否则交给拒判。

## local 2D refinement

若前端或局部判据显示 common-el 假设失配，则在局部 `(az, el)` 网格上计算 2D MUSIC 谱：

```text
P_2D(az, el) = 1 / ||E_n^H a(az, el)||_2^2
```

找到两个局部峰后检查空间分离和峰值比，合格才输出。

## confidence / boundary rejector

拒判优先级高于 success：

- `boundary_unreliable`：near anti-phase、边界冲突、多判据矛盾。
- `low_confidence`：MUSIC、rank1 fallback、2D refinement 都不足以支撑输出。
- `out_of_scope`：前端已经给出 two separated coarse peaks。

## 伪代码

```matlab
function out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg)

    if frontend_out.frontend_state is not single_peak_in_scope:
        out = make_reject_output(frontend_out.frontend_state)
        return

    selected = shared_center_select_subarray(frontend_out.coarseAz, array_geom, cfg.Q=65)

    Y_work = build_y_work_from_frontend(raw_cube, frontend_out, selected, cfg)
    % default derotation_mode = none

    music_info = local_cylindrical_music_test(Y_work, selected, array_geom, cfg)

    if music_info.is_two_peak_resolvable and music_info.confidence_ok:
        out = make_music_output(music_info)
        return

    coherent_info = coherent_rank1_refocus_fallback(Y_work, selected, array_geom, music_info, cfg)

    if coherent_info.valid and coherent_info.confidence_ok:
        out = make_coherent_pair_output(coherent_info)
        return

    if music_info.need_2d_refinement:
        pair2d_info = local_2d_pair_refinement(Y_work, selected, array_geom, cfg)
        if pair2d_info.valid and pair2d_info.confidence_ok:
            out = make_2d_pair_output(pair2d_info)
            return
        end
    end

    out = confidence_boundary_rejector(music_info, coherent_info, pair2d_info, cfg)
end
```

代码结构与上面的伪代码对应到 `main/` 下 7 个函数文件。
