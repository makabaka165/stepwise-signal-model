# Stage result tables

## Stage1

| Item | Value |
| --- | --- |
| goal | Sanity-check degree-based coarse-to-fine against full fine grid |
| key issue | Old index-based `el_sep` was physically inconsistent |
| before/after interpretation | Degree-based `el_sep` restores success and topK coverage, but default Stage1 window remains too conservative for acceleration |
| success | 1 |
| topK_miss | 0 |
| reduction | 1.11896672474 |
| pass flag | 0 |

## Stage2

| Item | Value |
| --- | --- |
| recommended config | coarse_016_024_minsep__topK3__refine_safe_fullsep |
| success | 1 |
| RMSE | 0.0765589261214 |
| num_pairs | 19161.9 |
| reduction | 6.86054096932 |
| topK miss | 0 |
| pass flag | 1 |

## Stage3

| Item | Value |
| --- | --- |
| bias cases | [0,0], [0.2,0], [0,0.2], [0.2,0.2], [-0.2,0], [0,-0.2] deg |
| zero bias success | 1 |
| max success drop | 0.06 |
| valid bias range | az_bias=[-0.20,0.20], el_bias=[-0.20,0.20] |
| pass flag | 1 |

## Missing source files

None.
