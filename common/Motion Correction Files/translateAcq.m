function mov = translateAcq(mov, xShift, yShift, fillval)

if nargin < 4
    fillval = nan;
end

[h, w, z] = size(mov);
referenceFrame = imref2d([h, w]);

parfor f = 1:z
%     if mod(f,250)==0
%         display(sprintf('Applying frame shift %d of %d',f,z)),
%     end

    tformMat = eye(3);
    tformMat(3, 1) = xShift(f);
    tformMat(3, 2) = yShift(f);
    tform = affine2d(tformMat);
    mov(:,:,f) = imwarp(mov(:,:,f), tform, ...
        'OutputView', referenceFrame, 'FillValues', fillval); 
end
end