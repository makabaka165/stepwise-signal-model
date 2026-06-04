# Algorithm Flow

```text
front-end coarse center
  -> local cylindrical work subarray
  -> local az/el beam matrix W
  -> beamspace snapshots Z = W'Y
  -> candidate models: common-el / controlled pair2d / full4d upper bound
  -> beamspace DML score J(Theta)
  -> two-target az/el estimate
  -> boundary and limitation label
```

The main thesis route uses controlled pair2d. Common-el is the baseline and full4d is the upper-bound reference.