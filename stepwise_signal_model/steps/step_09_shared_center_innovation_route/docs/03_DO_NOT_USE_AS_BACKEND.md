# Do Not Use Step09 as Final Backend

Do Not Use Step09 as Final Backend.

Reasons:

- Formal MC did not pass.
- Ablation did not pass.
- Bridge did not become default.
- Gate alignment failed safety.
- Final decision already points to Step8.7 verified lazy cascade.
- Continuing to tune Step09 will make the thesis route unclear.

The final thesis route is:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

If further algorithmic work is needed, do it as a new future-work branch, not inside the final thesis route.
