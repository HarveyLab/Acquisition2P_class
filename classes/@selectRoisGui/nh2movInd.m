function movInd = nh2movInd(sel, nhInd, nhCenter, nhSize)
% movInd = nh2movInd(sel, nhInd, nhCenter, nhSize) coverts linear indices
% into the covariance neighborhood region into linear indices into the
% whole movie frame.

if ~exist('nhCenter', 'var') || isempty(nhCenter)
    nhCenter = sel.disp.currentPos;
end

if ~exist('nhSize', 'var') || isempty(nhSize)
    nhSize = sel.roiInfo.covFile.nh;
end

nhCenter = round(nhCenter);

% Convert nh-indices into nh-subscripts:
[nhRow, nhCol] = ind2sub([nhSize nhSize], nhInd);

% Convert nh-subscripts into mov-subscripts:
margin = (sel.roiInfo.covFile.nh-1)/2;
movRow = nhRow - (margin+1) + nhCenter(1);
movCol = nhCol - (margin+1) + nhCenter(2);

% Out-of-bounds = nan:
movSize = sel.disp.movSize;
movRow(movRow<1 | movRow>movSize(1)) = nan;
movCol(movCol<1 | movCol>movSize(2)) = nan;

% Convert mov-subscripts into mov-indices:
movInd = sub2ind(movSize, movRow, movCol);