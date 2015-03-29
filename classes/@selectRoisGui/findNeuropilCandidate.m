function findNeuropilCandidate(sel)
% findNeuropilCandidate(sel) suggests which cluster corresponds to the
% neuropil by picking the cluster that is closest to the origin in
% correlation space. This is done in a low-dimensional embedding of the
% correlation space (using isomap MDS), because that seems to work better
% than working directly in the space of the full correlation matrix.

% Get 2-D MDS of correlation matrix:
x = isomap(1-sel.disp.corrMat, 2);

% Find cluster whose centroid is closest to [0, 0].
centRow = accumarray(sel.disp.currentClustering(:), x(:, 1), [], @mean);
centCol = accumarray(sel.disp.currentClustering(:), x(:, 2), [], @mean);
centDist = sqrt(centRow.^2 + centCol.^2);
centDist(sel.disp.currentClustInd) = inf; % Ignore the cluster currently selected by the user. 
[~, npCandidate] = min(centDist);

sel.disp.currentClustInd = npCandidate;