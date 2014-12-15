function calcPxCov(obj, movNums, radiusPxCov, temporalBin, sliceNum, channelNum, writeDir)
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

%% Loop over movies to get covariance matrix
nMovies = numel(movNums);
for m = 1:nMovies
    fprintf('Processing movie %03.0f of %03.0f.\n',find(movNums==m),length(movNums));
    loopTime = tic;
    
    %Load movie:
    if exist('parallelIo', 'var')
        % A parallelIo object was created in a previous iteration, so we
        % can simply retrieve the pre-loaded movie:
        fprintf('\nRetrieving pre-loaded movie %1.0f of %1.0f...\n',m,nMovies)
        [~, mov] = fetchNext(parallelIo);
        delete(parallelIo); % Delete data on parallel worker.
    else
        % No parallelIo exists, so this is either the first movie or
        % pre-loading is switched off, so we load the movie conventionally.
        fprintf('\nLoading movie %1.0f of %1.0f\n',m,nMovies)
        ticLoad = tic;
        mov = obj.readRaw(m,'single');
        fprintf('Done loading (%1.0f s).\n', toc(ticLoad));
    end
    
    % Re-start parallel pool. This is necessary to counteract a memory leak
    % in the parallel workers (this is an issue known to MathWorks): (This
    % will not pre-maturely abort parallelIo because the fetchNext blocks
    % Matlab until the parfeval finishes.)
    fprintf('Re-starting parallel pool to clear leaked memory:\n');
    delete(gcp);
    parpool;
    
    % Start parallel I/O job: This loads the mov for the next iteration:
    parallelIo = parfeval(@ioFun, 2, ...
        obj, [], m);
    
    % Bin temporally using reshape and sum, and center data
    mov = mov(:,:,1:end-rem(end, temporalBin)); % Deal with movies that are not evenly divisible.
    movSize = size(mov);
    [h, w, z] = size(mov);
    z = z/temporalBin;
    mov = squeeze(sum(reshape(mov,movSize(1)*movSize(2),temporalBin,movSize(3)/temporalBin),2));
    mov = bsxfun(@minus,mov,mean(mov,2));
    
    if m == 1
        nPix = w*h;

        % Neighborhood is square, and the edge length must be odd:
        nh = 2*round(radiusPxCov)+1;

        % Create an adjacency matrix for the first pixel. An adjacency
        % matrix is an nPixel-by-nPixel matrix that is 1 if pixel i and j
        % are within a neighborhood (i.e. we need to calculate their
        % covariance), and 0 elsewhere. In our case, this matrix has a
        % characterisitic pattern with sparse bands that run parallel to
        % the diagonal. Because nPix-by-nPix is large, we simply assemble a
        % list of linear indices:

        % ...Make list of diagonals in adjacency matrix that are 1,
        % following the convention of spdiags();
        diags = bsxfun(@plus, (-nh+1:nh-1)', 0:h:h*(nh-1));
        diags = diags(:)';
        diags(diags<0) = [];
        nDiags = numel(diags);

        % Calculate covariance:
        pixCov = zeros(nPix, nDiags, 'single');
    end
    
    parfor px = 1:nPix-diags(end)
        pixCov(px,:) = pixCov(px, :) + (mov(px, :)*mov(px+diags, :)')/z;
    end
    
    fprintf('Last movie took %3f seconds to process.\n', toc(loopTime));
end

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


function [mov, siStruct] = ioFun(obj, movieOrder, m, movStruct, writeDir, namingFunction)
% [mov, siStruct] = ioFun(obj, movieOrder, m, movStruct, writeDir, namingFunction)
% This function handles thes disk input/output for one iteration of the
% motion correction loop. By executing this function with parfeval, all I/O
% can be done in the background, while

if isempty(movieOrder)
    movieOrder = 1:m;
end

% Load movie for next iteration:
if m<numel(movieOrder)
    [mov, siStruct] = obj.readRaw(movieOrder(m+1), 'single', true);
else
    % There's nothing to be loaded if we're at the last movie in the
    % movieOrder:
    mov = [];
    siStruct = [];
end

% Stop here if there is nothing to be saved:
if m==1
    return
end

% Save movStruct from last iteration:
saveMovStruct(movStruct, writeDir, namingFunction, obj.acqName, movieOrder(m-1));
end
