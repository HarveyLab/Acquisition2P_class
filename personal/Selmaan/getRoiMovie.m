function mov = getRoiMovie(acq, roiNum, winSize)
% mov = getRoiMovie(acq, roiNum) returns a 3D mov stack of the image data
% in acq surrounding the roi roiNum.

h = acq.correctedMovies.slice(1).channel(1).size(1,1);
w = acq.correctedMovies.slice(1).channel(1).size(1,2);
nFramesTotal = sum(acq.correctedMovies.slice(1).channel(1).size(:,3));

% roiInd = acq.roiInfo.slice(1).roi(roiNum).indBody;
load(acq.roiInfo.slice.NMF.filename,'A')
roiInd = find(A(:,roiNum)>1e-10);

% Get centroid:
[r, c] = ind2sub([h, w], roiInd);
cr = round(mean(r));
cc = round(mean(c));

% Get list of pixels in neighborhood:
nh = winSize;
[nhC, nhR] = meshgrid(cc-nh:cc+nh, cr-nh:cr+nh);
nhC = min(max(nhC, 1), w);
nhR = min(max(nhR, 1), w);
nhInd = sub2ind(acq.correctedMovies.slice(1).channel(1).size(1,1:2), nhR, nhC);

% Get the pixels from the binary file:
movMap = memmapfile(acq.indexedMovie.slice(1).channel(1).fileName,...
    'Format', {'int16', [nFramesTotal, h*w], 'mov'});

mov = movMap.Data.mov(:, acq.mat2binInd(nhInd(:)));
mov = reshape(mov, nFramesTotal, 2*nh+1, 2*nh+1);
mov = permute(mov, [2, 3, 1]);
mov = single(mov);