function mov = getRoiMovie(acq, roiNum)
% mov = getRoiMovie(acq, roiNum) returns a 3D mov stack of the image data
% in acq surrounding the roi roiNum.

h = acq.derivedData(1).size(1);
w = acq.derivedData(1).size(2);
nFramesTotal = cat(1, acq.derivedData.size);
nFramesTotal = sum(nFramesTotal(:, 3));

roiInd = acq.roiInfo.slice(1).roi(roiNum).indBody;

% Get centroid:
[r, c] = ind2sub([h, w], roiInd);
cr = round(mean(r));
cc = round(mean(c));

% Get list of pixels in neighborhood:
nh = 20;
[nhC, nhR] = meshgrid(cc-nh:cc+nh, cr-nh:cr+nh);
nhC = min(max(nhC, 1), w);
nhR = min(max(nhR, 1), w);
nhInd = sub2ind(acq.derivedData(1).size(1:2), nhR, nhC);

% Get the pixels from the binary file:
movMap = memmapfile(acq.indexedMovie.slice(1).channel(1).fileName,...
    'Format', {'int16', [nFramesTotal, h*w], 'mov'});

mov = movMap.Data.mov(:, acq.mat2binInd(nhInd(:)));
mov = reshape(mov, nFramesTotal, 2*nh+1, 2*nh+1);
mov = permute(mov, [2, 3, 1]);
mov = single(mov);