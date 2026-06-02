# Problem Scope

The final thesis route is scoped to a holographic staring cylindrical array after the frontend chain has already produced a detection cell and a coarse angle. The local problem is a single coarse peak or unresolved local cluster, not arbitrary full-scene target separation.

The frontend state machine decides whether a detection enters the shared-center route. A `single_peak_in_scope` state enters the route. Two separated coarse peaks are kept outside this mainline because they are already a resolved frontend multi-peak condition and should be handled by a multi-target branch rather than by forcing a local unresolved-cluster solver.

Weak target and near anti-phase cases are treated as boundary protection cases. They may be visible in diagnostic scenarios, but the final method does not promote them to high-confidence estimates unless the verified backend and confidence state support that decision.

Success rate alone is not enough for this thesis route. The accepted route must also control:

- false-high: high-confidence output when the estimate is wrong;
- boundary-missed: boundary cases incorrectly treated as safe;
- low-confidence: cases correctly rejected or deferred;
- boundary-unreliable: cases where the route should not over-claim.

This is why the final route returns to Step8.7 verified lazy cascade instead of continuing Step09 threshold tuning. The chosen backend has a conservative safety profile, while Step09 gate variants improved some close-coherent success but failed false-high and single-target split safety.

