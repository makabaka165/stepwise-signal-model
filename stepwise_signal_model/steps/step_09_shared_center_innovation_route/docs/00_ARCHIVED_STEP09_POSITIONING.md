# Archived Step09 Positioning

Final backend = Step8.7 verified lazy cascade.

Step09 = archived diagnostics and thesis-interface notes.

## Original Goal

Step09 originally tried to turn the shared-center local work-subarray idea into a backend route. The intended chain was to take frontend coarse-angle output, choose a 65-column shared-center local subarray, build `Y_work`, and then test whether a Step09-light backend or a Step09-Step87 bridge could become the thesis backend.

## Why Step09 Backend Did Not Enter the Final Route

Step09 backend tuning did not close the required safety and reliability evidence:

- Formal MC did not pass.
- Ablation exposed that the Step09-light backend was weak in close-coherent and large-elevation cases.
- The Step09-Step87 bridge was useful diagnostically, but it did not become the default backend.
- Close-coherent diagnostics showed that candidate generation was not the main blocker; common-el gate mismatch was.
- Common-el gate alignment improved close-coherent success but failed safety through false-high and single-target false split behavior.

Because the final thesis route needs a conservative and clear backend, Step09 backend tuning is frozen.

## Relation To Step10

Step10 keeps the useful Step09 interface and framing layer, but freezes backend tuning. Step10 documents the final route:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

Step10 is therefore the final thesis-facing route. Step09 is the archive that explains why the abandoned backend attempts are not adopted.

## Relation To Step8.7

Step8.7 is the verified lazy cascade backend and the final performance evidence. Step09 does not replace Step8.7. The Step09-Step87 bridge is archived as diagnostic evidence only.

## Retained Value

Step09 still has value as:

- shared-center interface documentation;
- `Y_work` construction documentation;
- negative route-decision evidence;
- diagnostic record for close-coherent gate behavior;
- thesis framing support for why the final route returns to Step8.7.

## Why Not Continue Step09 Backend Tuning

Continuing Step09 backend tuning would make the thesis route unclear and would mix future algorithm exploration with the final evidence chain. Any further algorithmic work should be separated from the final thesis route.
