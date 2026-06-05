Step11.2 positioning
====================

Step11.1 already established the main backend route:

- controlled pair2d beamspace ML is the main algorithm;
- common-el is a baseline;
- local full4D is an upper bound;
- full4D did not improve the Step11.1 controlled pair2d success/RMSE enough
  to justify its candidate-count cost.

Step11.2 asks a narrower question: after fixing the controlled pair2d
beamspace ML backend, how should the transform matrix W be chosen?

Model
-----

The element-domain snapshots are modeled as:

```text
Y = A_cyl(Theta) S + N
```

The beamspace transform is:

```text
Z = W' Y
G(Theta) = W' A_cyl(Theta)
```

The fixed Step11.1 pair2d DML score uses:

```text
J(Theta) = trace(P_G Z Z')
P_G = G (G'G)^(-1) G'
```

W controls how much local manifold information is retained after reducing
from the active element domain to beamspace.

Allowed questions
-----------------

- How much local manifold energy is retained by each W?
- How correlated are nearby beamspace manifold pairs?
- How well conditioned are `W'W` and the selected pair `G'G`?
- Does a greedy subset of the existing engineering beam pool improve the fixed
  pair2d backend?
- Is the old regular 3dB-style grid already close to the SVD information
  upper bound?

Non-goals
---------

- replacing the Step11.1 backend;
- rerunning local full4D as the main route;
- adding AP;
- adding model-selection or confidence-boundary logic;
- doing element-domain ML as the main result;
- claiming a new front-end beam design.

