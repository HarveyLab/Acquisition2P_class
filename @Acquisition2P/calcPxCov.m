function calcPxCov(obj,movNums,widthPxCov,temporalBin,sliceNum,channelNum,writeDir)
%Function to calculate sparse pixel-pixel covariances at an array of seed
%points distributed throughout an image. 

% radiusPxCov - radius in pixels around seed point to include in covariance calculation
% seedBin - Factor by which image is divided/binned spatially to form grid of seed points
% temporalBin - Factor by which movie is binned temporally to facilitate covariance computation
% writeDir - Directory in which pixel covariance information will be saved

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
if ~exist('widthPxCov','var') || isempty(widthPxCov)
    widthPxCov = 10;
end 
if ~exist('temporalBin','var') || isempty(temporalBin)
    temporalBin = 8;
end 
if ~exist('writeDir','var') || isempty(writeDir)
    writeDir = obj.defaultDir;
end 

%% Loop over movies to get covariance matrix
tic,
for nMovie = movNums
    fprintf('Processing movie %03.0f of %03.0f. Last Movie took %1.0f s to process.\n',find(movNums==nMovie),length(movNums),toc),
    %Read movie, bin temporally using reshape and sum, and center data
    mov = readCor(obj,nMovie,'single');
    mov = mov(:,:,1:end-rem(end, temporalBin)); % Deal with movies that are not evenly divisible.
    movSize = size(mov);
    mov = squeeze(mean(reshape(mov,movSize(1),movSize(2),temporalBin,movSize(3)/temporalBin),3));
    mov = bsxfun(@minus,mov,mean(mov,3));
    tic,
    %First movie has to be handled differently than others, since it
    %preallocates memory and calculates pixel distances/neighbors for each
    %seed
    if nMovie == 1
        pxCov = nan(movSize(1),movSize(2),2*widthPxCov+1,2*widthPxCov+1,'single');
        iOff1 = nan(movSize(1),movSize(2));
        iOff2 = nan(movSize(1),movSize(2));
        jOff1 = nan(movSize(1),movSize(2));
        jOff2 = nan(movSize(1),movSize(2));
        for iPix = 1:movSize(1)
            for jPix = 1:movSize(2)
                iOff1(iPix,jPix) = (1+widthPxCov-iPix) * ((iPix-widthPxCov)<1);
                iOff2(iPix,jPix) = (iPix+widthPxCov-movSize(1)) * ((iPix+widthPxCov)>movSize(1));
                jOff1(iPix,jPix) = (1+widthPxCov-jPix) * ((jPix-widthPxCov)<1);
                jOff2(iPix,jPix) = (jPix+widthPxCov-movSize(2)) * ((jPix+widthPxCov)>movSize(2));
            end
        end
    end
    for iPix = 1:movSize(1)
        for jPix = 1:movSize(2)
            tMov = mov(iPix-widthPxCov+iOff1(iPix,jPix):iPix+widthPxCov-iOff2(iPix,jPix),...
                jPix-widthPxCov+jOff1(iPix,jPix):jPix+widthPxCov-jOff2(iPix,jPix),:);              
            pxCov(iPix,jPix,1+iOff1(iPix,jPix):end-iOff2(iPix,jPix),1+jOff1(iPix,jPix):end-jOff2(iPix,jPix)) = ...
                reshape(reshape(tMov,[],movSize(3)/temporalBin) * squeeze(mov(iPix,jPix,:)) ,...
                size(tMov,1),size(tMov,2)) / movSize(3);
        end
    end        
end

%Correct covariance by number of movies
% seedCov = seedCov / length(movNums);

%% Write results to disk
display('-----------------Saving Results-----------------')
covFileName = fullfile(writeDir,[obj.acqName '_covFile.mat']);
obj.roiInfo.slice(sliceNum).covFile = covFileName;
covFile = matfile(covFileName,'Writable',true);
covFile.widthPxCov = widthPxCov;
covFile.sliceNum = sliceNum;
covFile.channelNum = channelNum;
covFile.temporalBin = temporalBin;
covFile.iOff1 = iOff1;
covFile.iOff2 = iOff2;
covFile.jOff1 = jOff1;
covFile.jOff2 = jOff2;
covFile.pxCov = pxCov;