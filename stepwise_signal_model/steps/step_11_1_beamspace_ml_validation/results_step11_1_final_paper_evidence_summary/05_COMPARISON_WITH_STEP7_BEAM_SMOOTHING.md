# Comparison With Step7 Beam Smoothing

Step7 beam-index smoothing MUSIC uses sliding windows over beam indices. The weakness is that beam-index windows do not provide the physical translation invariance that true array subarrays provide.

Step11.1 does not use beam-index smoothing. It keeps the real cylindrical manifold and projects it into beamspace:

```text
G(Theta) = W'A_cyl(Theta)
```

Therefore the theoretical basis is different: Step11.1 evaluates physically parameterized cylindrical steering candidates in beamspace, instead of treating adjacent beam indices as a virtual shift-invariant array.