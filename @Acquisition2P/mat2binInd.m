function binPixInd = mat2binInd(obj, matPixInd)
% mat2binInd(acq, ind) converts a Matlab-conventional index into a movie
% frame into and index that can be used with the column-major binary movie
% file.

movRows = obj.derivedData(1).size(1);
movCols = obj.derivedData(1).size(2);

[pixRow, pixCol] = ind2sub([movRows, movCols], matPixInd);
binPixInd = sub2ind([movCols, movRows], pixCol, pixRow);