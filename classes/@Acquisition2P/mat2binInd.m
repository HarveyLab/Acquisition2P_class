function binPixInd = mat2binInd(obj, matPixInd)
% mat2binInd(acq, ind) converts a Matlab-conventional index (into a movie
% frame) into an index that can be used with the column-major binary movie
% file.

% Assume all slices and Channels have same image size
movRows = obj.correctedMovies.slice(1).channel(1).size(1,1);
movCols = obj.correctedMovies.slice(1).channel(1).size(1,2);

[pixRow, pixCol] = ind2sub([movRows, movCols], matPixInd);
binPixInd = sub2ind([movCols, movRows], pixCol, pixRow);