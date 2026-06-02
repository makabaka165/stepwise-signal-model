# Constraints Notes

No board-specific constraints are committed in Step12.

Future hardware work should add small, reviewable constraint files only after a target board is selected:

- clock and reset constraints;
- AXI / stream timing assumptions;
- pin constraints for board-level integration;
- false-path or multicycle constraints with justification.

Vivado/Vitis generated project files, runs, cache directories, bitstreams, reports, and waveform dumps are intentionally ignored.
