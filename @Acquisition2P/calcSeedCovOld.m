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


% CalcSeedCov is deprecated:
error('Do not use calcSeedCov -- use calcPxCov. If calcSeedCov is required for historical purposes, edid this error out of the file.');



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

maxNeighbors = round(pi*(radiusPxCov^2));
%% Loop over movies to get covariance matrix
tic,
for nMovie = movNums
    fprintf('Processing movie %03.0f of %03.0f. Last Movie took %3f to Process\n',find(movNums==nMovie),length(movNums),toc),
    %Read movie, bin temporally using reshape and sum, and center data
    mov = readCor(obj,nMovie,'single');
    mov = mov(:,:,1:end-rem(end, temporalBin)); % Deal with movies that are not evenly divisible.
    movSize = size(mov);
    mov = squeeze(sum(reshape(mov,movSize(1)*movSize(2),temporalBin,movSize(3)/temporalBin),2));
    mov = bsxfun(@minus,mov,mean(mov,2));
    tic,
    %First movie has to be handled differently than others, since it
    %preallocates memory and calculates pixel distances/neighbors for each
    %seed
    if nMovie == 1
        nPix = movSize(1)*movSize(2);
        nSeeds = round(movSize(1)/seedBin)*round(movSize(2)/seedBin);
        y = repmat(1:movSize(1),1,movSize(2));
        x = reshape(repmat(1:movSize(2),movSize(1),1),1,nPix);
        ySeed = repmat(1:round(movSize(1)/seedBin),1,round(movSize(2)/seedBin));
        xSeed = reshape(repmat(1:round(movSize(2)/seedBin),round(movSize(1)/seedBin),1),1,nSeeds);
        seedCov = nan(maxNeighbors,maxNeighbors,nSeeds,'single');
        pxNeighbors = nan(maxNeighbors,nSeeds,'single');
        nNeighbors = nan(1,nSeeds,'single');
        
        for seed = 1:nSeeds
            %Seed centroid is defined at xInd and yInd
            xInd = seedBin*(xSeed(seed)-1)+(seedBin+1)/2;
            yInd = seedBin*(ySeed(seed)-1)+(seedBin+1)/2;
            %The number and identity of pixels neighboring each seed are
            %stored for later use in nNeighbors and pxNeighbors
            dist2px = sqrt((x-xInd).^2 + (y-yInd).^2);
            tPx = find(dist2px<radiusPxCov);
            tNb = length(tPx);
            pxNeighbors(1:tNb,seed) = tPx;
            nNeighbors(seed) = tNb;
            seedCov(1:tNb,1:tNb,seed) = ...
                (mov(pxNeighbors(1:tNb,seed),:)*mov(pxNeighbors(1:tNb,seed),:)')/movSize(3);
        end        
    else
        %if not first movie, calculate px-px cov for all pixels for each seed
        for seed = 1:nSeeds
            tNb = nNeighbors(seed);
            pxN = pxNeighbors(1:tNb,seed);
            seedCov(1:tNb,1:tNb,seed) = seedCov(1:tNb,1:tNb,seed) + (mov(pxN,:)*mov(pxN,:)')/movSize(3);
        end
    end
end

%Correct covariance by number of movies summed
seedCov = seedCov / length(movNums);

%% Write results to disk
display('-----------------Saving Results-----------------')
covFileName = fullfile(writeDir,[obj.acqName '_covFile.mat']);
obj.roiInfo.slice(sliceNum).covFile = covFileName;
covFile = matfile(covFileName,'Writable',true);
covFile.radiusPxCov = radiusPxCov;
covFile.sliceNum = sliceNum;
covFile.channelNum = channelNum;
covFile.seedBin = seedBin;
covFile.temporalBin = temporalBin;
covFile.nNeighbors = nNeighbors;
covFile.pxNeighbors = pxNeighbors;
covFile.seedCov = seedCov;