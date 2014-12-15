function [covMat, qNhInd] = mmCovMat(pixCov, h, w, nh, qRow, qCol)

persistent mem queryCols indBlock2Diag covMatDiagsInd

if isempty(mem)
    mem.h = h;
    mem.w = w;
    mem.nh = nh;
else
    if ~(h==mem.h && w==mem.w && nh==mem.nh)
        % If any of these have changed, we need to re-calculate persistent
        % values:
        queryCols = [];
    end
end

% Build reconstruction index matrix using tril (can be stored between calls
% to this function):
if isempty(queryCols)
    L = tril(ones(nh));
    U = triu(ones(nh));
    E = [L, U(:, 1:end-1)];
    % E = [L, U];
    queryCols = repmat(E, nh, nh);
    queryCols = logical(queryCols(:, 1:end-nh+1));
end

% Make sure query pixel is within bounds:
margin = floor(nh/2);
qRow = min(max(qRow, margin+1), h-margin);
qCol = min(max(qCol, margin+1), w-margin);

% Find which rows we need to get from pixCov:
[qNhCols, qNhRows] = meshgrid(qCol-margin:qCol+margin, qRow-margin:qRow+margin);
qNhInd = sub2ind([h, w], qNhRows, qNhCols);
queryRows = qNhInd(:);

% Get covMat:
% 1. Get rows:
covMatRows = pixCov(queryRows, :);

% 2. Get cols using strange index matrix:
covMatDiags = nan(nh^2);

nElInRow = sum(queryCols, 2);
for ii = 1:nh^2
    covMatDiags(ii, 1:nElInRow(ii)) = covMatRows(ii, queryCols(ii, :));
end

covMat = diag2full(covMatDiags, 0:nh^2-1, nh^2, nh^2);
covMat = covMat+covMat'-diag(diag(covMat)); % Turn upper triangular into full matrix.

% [~, p] = chol(covMat);
% if p==0
%     fprintf('covMat is positive definite.\n');
% else    
%     warning('covMat is not positive definite. Repairing it...\n');
%     covMat = nearestSPD(covMat);
%     [~, p] = chol(covMat);
%     if p==0
%         fprintf('After correction, covMat is now positive definite.\n');
%     else
%         error('Can''t make it SPD.');
%     end
% end