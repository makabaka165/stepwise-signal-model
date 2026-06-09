# Step11.5 Stage2 Limitations And Final Recommendation

1. Stage2 is still not a new ML score.
2. Stage2 is not AP, full4D ML, or element-domain ML.
3. Config selection uses calibration split only; pass/fail uses validation split only.
4. Policy-degenerate configs are not allowed as positive adaptive results.
5. Bias robustness is verified for the selected config only.
6. Samples outside the verified bias range should enlarge windows or fall back to fixed/full fine search.

## Final recommendation

Stage2 passes validation and can be treated as a positive adaptive enhancement after Step11.3 fixed topK3.

recommended_next_step = `use_step11_5_stage2_as_positive_adaptive_enhancement`
