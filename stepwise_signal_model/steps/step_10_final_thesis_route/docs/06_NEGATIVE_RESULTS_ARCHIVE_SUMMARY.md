# Negative Results Archive Summary

The negative results are not mainline failures. They are route-convergence evidence: they show which tempting routes should not be used for the final thesis backend.

1. Step09-light backend is not adopted because it did not provide a validated safety improvement over Step8.7.
2. Step09 formal MC exposed that Step09-light should not be promoted to final performance evidence.
3. Step09 ablation showed that removing or changing conservative components can improve selected cases but weakens safety behavior.
4. Step09-Step87 bridge was useful as a diagnostic bridge, but it did not become the final default backend.
5. Close coherent gate diagnostics showed that truth can enter top-K candidates, but the gate logic still does not safely release final decisions.
6. common-el gate alignment recovered close-coherent success to `0.87333`, but failed safety with `overall_false_high_rate = 0.034722` and `single_target_false_split_rate = 0.83333`.
7. Step8.10 unified model selection is not adopted because `unified_success_overall = 0.0850290697674419`, `unified_false_high = 0.222383720930233`, and threshold validation did not pass.
8. Step8.9 fixed-point validation is not a complete hardware success because `fixed_point_pass_flag = 0` and the blocker is `quantization_not_closed`.

The resulting decision is to freeze Step09 backend tuning and use Step8.7 verified lazy cascade as the final backend evidence.

