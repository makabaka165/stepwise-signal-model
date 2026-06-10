function validation = validate_step11_7_backend_input(input, context)
%VALIDATE_STEP11_7_BACKEND_INPUT Validate Step11.7 frontend-like input.

validation = struct();
validation.valid = false;
validation.backend_ran_flag = false;
validation.status = 'invalid_input';
validation.confidence = 'low';
validation.boundary_flag = '';
validation.error_message = '';
validation.frontend_state = '';
validation.reshape_mode = '';
validation.Y = [];
validation.input_shape = '';

required = {'Y_work','frontend_state','coarseAz','coarseEl','selectedCenterColumn','selectedCenterAz'};
for idx = 1:numel(required)
    if ~isstruct(input) || ~isfield(input, required{idx})
        validation.error_message = sprintf('missing required input.%s', required{idx});
        return;
    end
end

validation.frontend_state = char(input.frontend_state);
if any(strcmp(validation.frontend_state, context.unsupported_frontend_states))
    validation.status = 'out_of_scope';
    validation.boundary_flag = 'frontend_state_not_supported';
    validation.error_message = sprintf('unsupported frontend_state: %s', validation.frontend_state);
    return;
end
if ~any(strcmp(validation.frontend_state, context.supported_frontend_states))
    validation.status = 'out_of_scope';
    validation.boundary_flag = 'frontend_state_not_supported';
    validation.error_message = sprintf('unknown frontend_state: %s', validation.frontend_state);
    return;
end

Y_work = input.Y_work;
sz = size(Y_work);
validation.input_shape = shape_text_local(sz);
N = size(context.W, 1);
if ismatrix(Y_work) && size(Y_work, 1) == N && size(Y_work, 2) >= 1
    validation.Y = Y_work;
    validation.reshape_mode = 'already_N_by_L';
elseif ndims(Y_work) == 3 && sz(1) == context.cfg.beam.subNaz && sz(2) == context.cfg.arr.Nel && sz(3) >= 1
    validation.Y = reshape(Y_work, [], sz(3));
    validation.reshape_mode = 'reshape_65x32xT_to_N_by_T';
else
    validation.error_message = sprintf('Y_work shape %s does not match W element count %d or 65x32xT.', validation.input_shape, N);
    return;
end

numeric_fields = {'coarseAz','coarseEl','selectedCenterColumn','selectedCenterAz'};
for idx = 1:numel(numeric_fields)
    value = input.(numeric_fields{idx});
    if ~(isscalar(value) && isfinite(value))
        validation.error_message = sprintf('input.%s must be a finite scalar', numeric_fields{idx});
        return;
    end
end

validation.valid = true;
validation.status = 'ok';
validation.backend_ran_flag = true;
validation.confidence = 'candidate';
end

function text = shape_text_local(sz)
parts = cell(1, numel(sz));
for idx = 1:numel(sz)
    parts{idx} = sprintf('%d', sz(idx));
end
text = strjoin(parts, 'x');
end
