function [clusterIndex, clusterCentroid] = getClusters(sel, nCuts, nClusters)
% getClusters(sel, nCuts, nClusters) performs k-means clustering on the
% normcuts data. This function should be used wherever clustering is done,
% rather than using kmeans() separately in different places.

cutVecs = sel.disp.cutVecs(:,1:nCuts);
nPix = size(cutVecs, 1);

% Choose starting points for clustering based on salient features in the
% cuts:
mostSalientPix = abs(bsxfun(@minus, cutVecs, median(cutVecs)));
[~, startInd] = max(mostSalientPix);
start = cutVecs(startInd, :);

% Use random points for any additional clusters:
if nCuts>nClusters
    start = start(1:nClusters, :);
elseif nCuts<nClusters
    nReps = 10;
    randInd = randi(nPix, (nClusters-nCuts)*nReps, 1);
    randStartPoints = cutVecs(randInd, :);
    randStartPoints = reshape(randStartPoints', [], (nClusters-nCuts), nReps);
    randStartPoints = permute(randStartPoints, [2, 1, 3]);
    start = cat(1, repmat(start, 1, 1, nReps), randStartPoints);
end

[clusterIndex, clusterCentroid] = ...
    kmeans(cutVecs, nClusters, 'Distance', 'cityblock', 'MaxIter', 1e2, ...
    'start', start);