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
    if m==1
        % Load first movie conventionally:
        fprintf('\nLoading Movie #%03.0f of #%03.0f\n',movNums(m),nMovies)
        mov = obj.readRaw(movNums(m),'single');
    else
        % Following movies: Retrieve movie that was loaded in parallel:
        fprintf('\nRetrieving pre-loaded movie #%03.0f of #%03.0f\n',movNums(m),nMovies)
        mov = fetchOutputs(parObjRead);
        delete(parObjRead); % Necessary to delete data on parallel worker.
    end
    
    % Start parallel loading of next movie:
    if m<nMovies
        % Start loading on parallel worker:
        isSilent = true;
        parObjRead = parfeval(@obj.readCor, 1, movNums(m+1), 'single', isSilent);
    end    
    
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
    
    for px = 1:nPix-diags(end)
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