function calcSeedCov(obj,movNums,radiusPxCov,seedBin,temporalBin,sliceNum,channelNum,writeDir)
%Function to calculate sparse pixel-pixel covariances at an array of seed
%points distributed throughout an image. 
%
% calcSeedCov(obj,movNums,radiusPxCov,seedBin,temporalBin,sliceNum,channelNum,writeDir)
%
% movNums - vector-list of movie numbers to use for calculation. defaults to 1:length(fileName)
% radiusPxCov - radius in pixels around seed point to include in covariance calculation, defaults to 10.5
% seedBin - Factor by which image pixel locations are divided/binned spatially to form grid of seed points, defaults to 4
% temporalBin - Factor by which movie is binned temporally to facilitate covariance computation, defaults to 8
% writeDir - Directory in which pixel covariance information will be saved, defaults to obj.defaultDir

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
    radiusPxCov = 10.5;
end 
if ~exist('seedBin','var') || isempty(seedBin)
    seedBin = 4;
end 
if ~exist('temporalBin','var') || isempty(temporalBin)
    temporalBin = 8;
end 
if ~exist('writeDir','var') || isempty(writeDir)
    writeDir = obj.defaultDir;
end 

%% Loop over movies to get covariance matrix
for nMovie = movNums
    fprintf('Processing movie %03.0f of %03.0f.\n',find(movNums==nMovie),length(movNums));
    loopTime = tic;
    %Read movie, bin temporally using reshape and sum, and center data
    mov = readCor(obj,nMovie,'single');
    mov = mov(:,:,1:end-rem(end, temporalBin)); % Deal with movies that are not evenly divisible.
    movSize = size(mov);
    [h, w, z] = size(mov);
    z = z/temporalBin;
    mov = squeeze(sum(reshape(mov,movSize(1)*movSize(2),temporalBin,movSize(3)/temporalBin),2));
    mov = bsxfun(@minus,mov,mean(mov,2));
    
    if nMovie == 1
        nPix = w*h;

        % Neighborhood is square, and the edge length must be odd:
        nh = 2*round(radiusPxCov)+1;

        % Create an adjacency matrix for the first pixel. An adjacency matrix is an
        % nPixel-by-nPixel matrix that is 1 if pixel i and j are within a
        % neighborhood (i.e. we need to calculate their covariance), and 0
        % elsewhere. In our case, this matrix has a characterisitic pattern with
        % sparse bands that run parallel to the diagonal. Because nPix-by-nPix is
        % large, we simply assemble a list of linear indices:

        % ...Make list of diagonals in adjacency matrix that are 1, following
        % the convention of spdiags();
        diags = row(bsxfun(@plus, (-nh+1:nh-1)', 0:h:h*(nh-1)));
        diags(diags<0) = [];
        nDiags = numel(diags);

        % Calculate covariance:
        pixCov = zeros(nPix, nDiags, 'single');
    end
    
    for px = 1: nPix-diags(end)
        pixCov(px,:) = pixCov(:, px)+ (mov(px, :) * mov(px+diags, :)')/z;
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
covFileName = fullfile(writeDir,[obj.acqName '_pixCovFile.mat']);
obj.roiInfo.slice(sliceNum).covFile = covFileName;
covFile = matfile(covFileName,'Writable',true);
covFile.nh = nh;
covFile.sliceNum = sliceNum;
covFile.channelNum = channelNum;
covFile.temporalBin = temporalBin;
covFile.pixCov = pixCov;
covFile.activityImg = calcActivityOverviewImg(pixCov, diags, h, w);