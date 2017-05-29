function extractSources(acq,nSlice,data,initImages) %extractSources(acq,nSlice,useLocal)

% Wrapper function for NMF-based source extraction.

if ~exist('nSlice','var') || isempty(nSlice)
    nSlice = 1;
end

if ~exist('data','var')
    data = [];
end

if ~exist('initImages','var')
    initImages = [];
end

% if ~exist('useLocal','var') || isempty(useLocal)
%     useLocal = 1;
% end

% if useLocal
%     tempDir = 'E:\memmaps\tmp';
%     thisSliceDir = acq.indexedMovie.slice(nSlice).channel(1).fileName;
%     tempMovDir = fullfile(tempDir,'tempMov.bin');
%     fprintf('\n Copying binary file to %s',tempDir),
%     status = copyfile(thisSliceDir,tempMovDir,'f');
%     if status
%         acq.indexedMovie.slice(nSlice).channel(1).fileName = tempMovDir;
%     else
%         warning('Failure to copy data locally'),
%     end
% end
    

% NMF code requires syncInfo. Create minimal version if none is present:
if isempty(acq.syncInfo) || ~isfield(acq.syncInfo, 'sliceFrames')
    % Create minimal syncInfo:
    nSlices = length(acq.correctedMovies.slice);
    acqInd = cellfun(@(s) str2double(s(end-14:end-10)), acq.Movies);
    iAcq = unique(acqInd)';
    nBlocks = length(iAcq);
    for nBlock = 1:nBlocks
        theseMovs = acqInd==iAcq(nBlock);
        blockEnd = find(theseMovs,1,'last');
        for thisSlice = 1:nSlices
            sliceFrames(nBlock,thisSlice) = ...
                sum(acq.correctedMovies.slice(thisSlice).channel(1).size(1:blockEnd, 3));
        end
        
        if nBlock > 1
            validFrameCount(nBlock) = min(sliceFrames(nBlock,:)-sliceFrames(nBlock-1,:));
        else
            validFrameCount(nBlock) = min(sliceFrames(nBlock,:));
        end
    end
    
    if nSlices > 1
        validFrameCount = validFrameCount*(nSlices+1);
    end
    
    acq.syncInfo.sliceFrames = sliceFrames;
    acq.syncInfo.validFrameCount = validFrameCount;
end

% Run:
extractSourcesNMF(acq,nSlice,data,initImages);

% if useLocal
%     acq.indexedMovie.slice(nSlice).channel(1).fileName = thisSliceDir;
%     delete(tempMovDir),
% end