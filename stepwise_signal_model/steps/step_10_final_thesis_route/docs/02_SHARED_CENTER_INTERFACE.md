# Shared-Center Interface

The shared-center interface converts a frontend coarse angle into a fixed local cylindrical manifold.

```text
selectedCenterColumn = argmin_k |wrap180(phiCol(k) - coarseAz)|
selectedWorkColumns = selectedCenterColumn + [-32, ..., 0, ..., +32]
Y_work in C^(65 x 32 x Np)
```

Interface meaning:

- `coarseAz` comes from frontend detection and coarse beamforming.
- The 65 columns form the local work subarray.
- The 32 elevation layers preserve elevation information.
- `Y_work` is the local observation input to the Step8.7 backend.
- The default route does not enable Doppler de-rotation.

The interface value is that it converts the global cylindrical array problem into a standardized local manifold. This lets the thesis describe a stable handoff from frontend detection to conservative enhanced DOA estimation without requiring a new Step09 backend.

Retained Step09 interface files:

- `steps/step_09_shared_center_innovation_route/main/shared_center_select_subarray.m`
- `steps/step_09_shared_center_innovation_route/main/build_y_work_from_frontend.m`

