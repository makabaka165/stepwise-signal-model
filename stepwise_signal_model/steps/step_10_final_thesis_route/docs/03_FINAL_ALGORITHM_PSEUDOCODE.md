# Final Algorithm Pseudocode

The final algorithm uses the shared-center interface and the original Step8.7 verified lazy cascade backend. It does not use Step09-light as the backend.

```matlab
function out = final_shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg)

    if frontend_out.frontend_state ~= "single_peak_in_scope"
        out = make_low_confidence_or_out_of_scope(frontend_out);
        return
    end

    selected = shared_center_select_subarray(frontend_out.coarseAz, array_geom, 65);

    Y_work = build_y_work_from_frontend(raw_cube, frontend_out, selected);

    out = step87_verified_lazy_cascade_backend(Y_work, selected, frontend_out, array_geom, cfg);

    out.selectedCenterColumn = selected.selectedCenterColumn;
    out.selectedWorkColumns = selected.selectedWorkColumns;
    out.Y_work_shape = size(Y_work);
    out.method = "shared-center enhanced DOA with Step8.7 verified backend";

end
```

Backend mapping:

- `step87_verified_lazy_cascade_backend` corresponds to the original Step8.7 verified lazy cascade.
- Truth labels are used only for validation and reporting. They do not enter route decisions.
- Step09-light, the Step09 Step87 bridge, and common-el gate alignment are not final default backends.

The implementation intent is conservative: a detection that is out of scope or unsafe should produce low-confidence or boundary output rather than a forced high-confidence pair estimate.

