# Complexity reduction analysis

Full fine candidates: `131461`.

Coarse-to-fine candidates: `19161.9`.

Reduction: `6.86054096932`.

The candidate scoring count is reduced by about 85.4%.

The coarse grid uses fewer candidates to locate the topK promising ML-score regions. The refine stage then searches only within local windows around those topK candidates. Every candidate is still scored by the same controlled pair2d DML score, so this is a search-complexity reduction rather than a different ML model.
