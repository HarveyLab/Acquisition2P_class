function extractSources(acq,nSlice,nChannel)

% Wrapper function for NMF-based source extraction.

if ~exist('nSlice','var') || isempty(nSlice)
    nSlice = 1;
end

if ~exist('nChannel','var') || isempty(nChannel)
    nChannel = 1;
end


% NMF code requires syncInfo. Create minimal version if none is present:
if isempty(acq.syncInfo) || ~isfield(acq.syncInfo, 'sliceFrames')
    % Create minimal syncInfo:
    nSlices = length(acq.correctedMovies.slice);
    movList = cell2mat(acq.Movies');
    acqInd = str2num(movList(:,end-14:end-10));
    iAcq = unique(acqInd)';
    nBlocks = length(iAcq);
    for nBlock = 1:nBlocks
        theseMovs = acqInd==iAcq(nBlock);
        for nSlice = 1:nSlices
            sliceFrames(nBlock,nSlice) = ...
                sum(acq.correctedMovies.slice(nSlice).channel.size(theseMovs, 3));
        end
        
        if nBlock > 1
            validFrameCount(nBlock) = min(sliceFrames(nBlock,:)-sliceFrames(nBlock-1,:));
        else
            validFrameCount(nBlock) = min(sliceFrames(nBlock,:));
        end
    end      

    acq.syncInfo.sliceFrames = sliceFrames;
    acq.syncInfo.validFrameCount = validFrameCount;
end

% Run:
extractSourcesNMF(acq,nSlice);