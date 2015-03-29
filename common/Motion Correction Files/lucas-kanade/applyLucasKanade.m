function mov = applyLucasKanade(mov, dpx, dpy, B, xGlobal, yGlobal)


if ~exist('xGlobal', 'var') || isempty(xGlobal)
    xGlobal = 0;
end
if ~exist('yGlobal', 'var') || isempty(yGlobal)
    yGlobal = 0;
end

[h, w, z] = size(mov);

% Get full displacement fields:
Dx = dispFieldX(h, w, z, B, dpx, xGlobal);
Dy = dispFieldY(h, w, z, B, dpy, yGlobal);

for f = 1:z
    f
    mov(:,:,f) = interp2(mov(:,:,f), Dx(:,:,f), Dy(:,:,f), 'linear');
end

end


function dx = dispFieldX(h, w, z, basisFunctions, dpx, xGlobal)
    lineShiftX = zeros(h, z);
    for f = 1:z
        lineShiftX(:, f) = basisFunctions*dpx(:, f) - xGlobal;
    end
    dx = bsxfun(@plus, 1:w, permute(lineShiftX, [1, 3, 2]));
end

function dy = dispFieldY(h, w, z, basisFunctions, dpy, yGlobal)
    lineShiftY = zeros(h, z);
    for f = 1:z
        lineShiftY(:, f) = basisFunctions*dpy(:, f) - yGlobal;
    end
    dy = bsxfun(@plus, zeros(1, w), permute(bsxfun(@plus, (1:h)', lineShiftY), [1, 3, 2]));
end