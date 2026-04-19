function grid = build_sector_beam_grid(modeName, cfg, truth, azCenterDeg, elCenterDeg)
%BUILD_SECTOR_BEAM_GRID 先测参考波束宽度，再构造居中的一维波束网格。
% modeName 取 'azimuth' 或 'elevation'。

ref = analyze_reference_beam(modeName, cfg, truth, azCenterDeg, elCenterDeg);

if strcmpi(modeName, 'azimuth')
    % 方位维直接在物理角度空间中按参考波束宽度排布。
    minVal = azCenterDeg + min(truth.phiUseRel);
    maxVal = azCenterDeg + max(truth.phiUseRel);
    spacing = ref.bw3dB;
    beamGrid = build_left_aligned_beam_grid(minVal, spacing, maxVal);

    grid = struct();
    grid.modeName = 'azimuth';
    grid.center = azCenterDeg;
    grid.spacing = spacing;
    grid.minVal = minVal;
    grid.maxVal = maxVal;
    grid.beam = beamGrid;
    grid.ref = ref;
    return;
end

beam = cfg.beam;
% 俯仰维先转到 u 域排布，再映射回物理俯仰角。
uCenter = sind(elCenterDeg);
uMin = sind(beam.elBeamMinDeg);
uMax = sind(beam.elBeamMaxDeg);
spacing = ref.bw3dBU;
uBeam = build_left_aligned_beam_grid(uMin, spacing, uMax);

grid = struct();
grid.modeName = 'elevation';
grid.center = elCenterDeg;
grid.uCenter = uCenter;
grid.spacing = spacing;
grid.minVal = beam.elBeamMinDeg;
grid.maxVal = beam.elBeamMaxDeg;
grid.uMin = uMin;
grid.uMax = uMax;
grid.beam = asind(uBeam);
grid.uBeam = uBeam;
grid.ref = ref;
end
