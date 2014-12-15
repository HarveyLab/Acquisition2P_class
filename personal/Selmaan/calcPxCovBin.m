function calcPxCovBin(obj, movNums, radiusPxCov, temporalBin, sliceNum, channelNum, writeDir)
% calcPxCov(obj, movNums, radiusPxCov, temporalBin, sliceNum, channelNum,
% writeDir) Function to calculate all pixel-pixel covariances within a
% square neighborhood around each pixel. Size of the neighborhood is
% radiusPxCov pixels in all directions around the center pixel.
%
% movNums - vector-list of movie numbers to use for calculation. defaults
% to 1:length(fileName)
%
% radiusPxCov - radius in pixels around each pixel to include in covariance
% calculation, defaults to 11 (despite the term "radius", the
% neighborhood will be square, with an edge length of radius*2+1).
%
% temporalBin - Factor by which movie is binned temporally to facilitate
% covariance computation, defaults to 8
%
% writeDir - Directory in which pixel covariance information will be saved,
% defaults to obj.defaultDir

%% Input handling / Error Checking
if ~exist('sliceNum','var') || isempty(sliceNum)
    sliceNum = 1;
end
if ~exist('channelNum','var') || isempty(channelNum)
    channelNum = 1;
end
if ~exist('movNums','var') || isempty(movNums)
    movNums = 1:length(obj.correctedMovies.slice(sliceNum).channel(channelNum).fileName);
end
if ~exist('radiusPxCov','var') || isempty(radiusPxCov)
    radiusPxCov = 11;
end 
if ~exist('temporalBin','var') || isempty(temporalBin)
    temporalBin = 8;
end 
if ~exist('writeDir','var') || isempty(writeDir)
    writeDir = obj.defaultDir;
end

%% Initialize/Allocate Variables

% Create memory mapped binary file of movie:
movSizes = [obj.derivedData.size];
movLengths = movSizes(3:3:end);
movMap = memmapfile(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
    'Format', {'int16', [sum(movLengths), movSizes(1)*movSizes(2)], 'mov'});
mov = movMap.Data.mov;

% Get movie size information
[nFramesTotal, nPix] = size(mov);
nFrames = nFramesTotal - rem(nFramesTotal, temporalBin);
h = movSizes(1);
w = movSizes(2);
nh = 2*round(radiusPxCov)+1;

% Create adjacency indices
diags = bsxfun(@plus, (-nh+1:nh-1)', 0:h:h*(nh-1));
diags = diags(:)';
diags(diags<0) = [];
nDiags = numel(diags);

% Preallocate covariance array
pixCov = zeros(nPix, nDiags, 'single');

%% Loop over movies to get covariance matrix

tic,
for px = 1:nFrames
    pixCov(px,:) = (sum(reshape(mov(1:nFrames, px), temporalBin, nFrames/temporalBin),1) ...
        * squeeze(sum(reshape(mov(1:nFrames, px+diags), temporalBin, nFrames/temporalBin, nDiags),1))) / nFrames;
end
toc,

% Shift into SPDIAGS format:
for ii = 1:nDiags
    pixCov(:, ii) = circshift(pixCov(:, ii), diags(ii));
end

%Correct covariance by number of movies summed
pixCov = pixCov / length(movNums);

%% Write results to disk
display('-----------------Saving Results-----------------')
covFileName = fullfile(writeDir,[obj.acqName '_pixCovFile.bin']);

% Write binary file to disk:
fileID = fopen(covFileName,'w');
fwrite(fileID, pixCov, 'single');
fclose(fileID);

% Save metadata in acq2p:
obj.roiInfo.slice(sliceNum).covFile.fileName = covFileName;
obj.roiInfo.slice(sliceNum).covFile.nh = nh;
obj.roiInfo.slice(sliceNum).covFile.nPix = nPix;
obj.roiInfo.slice(sliceNum).covFile.nDiags = nDiags;
obj.roiInfo.slice(sliceNum).covFile.diags = diags;
obj.roiInfo.slice(sliceNum).covFile.channelNum = channelNum;
obj.roiInfo.slice(sliceNum).covFile.temporalBin = temporalBin;
obj.roiInfo.slice(sliceNum).covFile.activityImg = calcActivityOverviewImg(pixCov, diags, h, w); 