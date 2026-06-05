Stage3 frontend-prior bias robustness plan
==========================================

Stage3 validates the recommended coarse-to-fine configuration under simulated
front-end coarse-center bias.

Bias cases:

```text
[ 0.0,  0.0]
[ 0.2,  0.0]
[ 0.0,  0.2]
[ 0.2,  0.2]
[-0.2,  0.0]
[ 0.0, -0.2]
```

These biases emulate front-end coarse-angle error and are not truth inputs.

Pass rule:

- every bias case has coarse-to-fine success at least 90% of zero-bias success;
- topK miss rate no more than 0.1;
- boundary-hit rate no more than 0.2.

