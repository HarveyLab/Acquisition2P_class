function [covMat, pxNeighbors] = getCovData(sel, queryNhRad)
% [covMat, pixNeighbors] = getCovData(hFig) extracts the covariance data
% for one "seed" pixel from the covFile. This function deals with the
% different covFile formats.
persistent mem queryCols nElInRow

% Simplify variable names:
h = sel.disp.movSize(1);
w = sel.disp.movSize(2);
qRow = round(sel.disp.currentPos(1));
qCol = round(sel.disp.currentPos(2));
nh = sel.roiInfo.covFile.nh;

if nargin<2
    queryNhRad = floor(nh/2);
    qNh = nh;
else
    queryNhRad = max(min(queryNhRad, floor(nh/2)), 0);
    qNh = queryNhRad*2 + 1;
end

% Pre-calculate and store queryCols between calls: (queryCols is a matrix
% that indexes into the stored covariance matrix file to retrieve queried
% columns of the matrix. It doens't change between calls.)
if isempty(mem)
    mem.h = h;
    mem.w = w;
    mem.nh = nh;
end
if isempty(queryCols) || h~=mem.h || w~=mem.w || nh~=mem.nh
    % If queryCols is empty or the size of the nh has changed, we need to
    % recalculate:
    L = tril(ones(nh));
    U = triu(ones(nh));
    E = [L, U(:, 1:end-1)];
    % E = [L, U];
    queryCols = repmat(E, nh, nh);
    queryCols = logical(queryCols(:, 1:end-nh+1));
    nElInRow = sum(queryCols, 2);
end

% Make sure query pixel is within bounds:
margin = floor(nh/2);
qRow = min(max(qRow, margin+1), h-margin);
qCol = min(max(qCol, margin+1), w-margin);

% Find which rows we need to get from pixCov:
[qNhCols, qNhRows] = meshgrid(qCol-queryNhRad:qCol+queryNhRad, qRow-queryNhRad:qRow+queryNhRad);
pxNeighbors = sub2ind([h, w], qNhRows, qNhCols);
queryRows = pxNeighbors(:);

% Get covMat:
% 1. Get rows:
pixCov = sel.covMap.Data.pixCov;
covMatRows = pixCov(queryRows,:);

% 2. Get cols using strange index matrix:
covMatDiags = nan(qNh^2);
for ii = 1:qNh^2
    covMatDiags(ii, 1:nElInRow(ii)) = covMatRows(ii, queryCols(ii, :));
end

covMat = diag2full(covMatDiags, 0:qNh^2-1, qNh^2, qNh^2);
covMat = covMat+covMat'-diag(diag(covMat)); % Turn upper triangular into full matrix.
end