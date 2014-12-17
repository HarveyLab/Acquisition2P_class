function addMovieSizes(acq)
% Function to find and store movie size information in old acquisition
% objects that did not calculate this info during motion correction.

if isfield(acq.correctedMovies.slice(1).channel(1), 'size')
    warning('This acquisition already has size information. Will not change anything.');
end


% The size should be equal for all slices and channels, so we just check the
% first of each:
sl = 1;
ch = 1;

movList = acq.correctedMovies.slice(sl).channel(ch).fileName;

for m = 1:numel(movList)            
    % Determine dimensions. Since it is slow to open the TIFF and
    % count the frames, we assume that files with the same size
    % have the same dimensions:
    if m==1
        movSizes(m,:) = tiffDimensions(movList{m});
        fileInfo = dir(movList{m});
        prevBytes = fileInfo.bytes;
        prevDimensions = movSizes(m,:);
    else
        fileInfo = dir(movList{m});
        if fileInfo.bytes==prevBytes
            movSizes(m,:) = prevDimensions;
        else
            movSizes(m,:) = tiffDimensions(movList{m});
            fileInfo = dir(movList{m});
            prevBytes = fileInfo.bytes;
            prevDimensions = movSizes(m,:);
        end 
    end
end

for nSlice = 1:length(acq.correctedMovies.slice)
    for nChannel = 1:length(acq.correctedMovies.slice(nSlice).channel)
            acq.correctedMovies.slice(nSlice).channel(nChannel).size = movSizes;
    end
end