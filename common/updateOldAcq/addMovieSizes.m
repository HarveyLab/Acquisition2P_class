function addMovieSizes(acq)
% Function to find and store movie size information in old acquisition
% objects that did not calculate this info during motion correction.

if isfield(acq.derivedData, 'size')
    warning('This acquisition already has size information. Will not change anything.');
end


% The size must be equal for all slices and channels, so we just check the
% first of each:
sl = 1;
ch = 1;

movList = acq.correctedMovies.slice(sl).channel(ch).fileName;

for m = 1:numel(movList)            
    % Determine dimensions. Since it is slow to open the TIFF and
    % count the frames, we assume that files with the same size
    % have the same dimensions:
    if m==1
        acq.derivedData(m).size = tiffDimensions(movList{m});
        fileInfo = dir(movList{m});
        prevBytes = fileInfo.bytes;
        prevDimensions = acq.derivedData(m).size;
    else
        fileInfo = dir(movList{m});
        if fileInfo.bytes==prevBytes
            acq.derivedData(m).size = prevDimensions;
        else
            acq.derivedData(m).size = tiffDimensions(movList{m});
            fileInfo = dir(movList{m});
            prevBytes = fileInfo.bytes;
            prevDimensions = acq.derivedData(m).size;
        end 
    end
end