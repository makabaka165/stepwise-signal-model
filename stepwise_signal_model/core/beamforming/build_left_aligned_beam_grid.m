function grid = build_left_aligned_beam_grid(minVal, spacing, maxVal)
%BUILD_LEFT_ALIGNED_BEAM_GRID Generate an equally spaced beam grid from the left edge.
if spacing <= 0
    error('spacing must be positive.');
end

if minVal > maxVal
    error('minVal cannot exceed maxVal.');
end

tol = 1e-10 * max(1, max(abs([minVal, maxVal])));
nBeam = floor((maxVal - minVal) / spacing + tol) + 1;
nBeam = max(nBeam, 1);

grid = minVal + (0:nBeam - 1) * spacing;
grid = grid(grid >= minVal - tol & grid <= maxVal + tol);
grid = grid(:).';
end
