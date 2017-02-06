function [clusterIndex, clusterCentroid] = getClusters(sel, nCuts, nClusters)
% getClusters(sel, nCuts, nClusters) performs k-means clustering on the
% normcuts data. This function should be used wherever clustering is done,
% rather than using kmeans() separately in different places.

cutVecs = sel.disp.cutVecs(:,(1+sel.disp.cutMod_nTopToExclude):nCuts);
nPix = size(cutVecs, 1);

% Choose starting points for clustering based on salient features in the
% cuts:
mostSalientPix = abs(bsxfun(@minus, cutVecs, median(cutVecs)));
[~, startInd] = max(mostSalientPix);
startInd = unique(startInd,'stable');
nCentroids = length(startInd);

startCent = cutVecs(startInd, :);

% Use random points for any additional clusters:
if nCentroids>nClusters
    startCent = startCent(1:nClusters, :);
elseif nCentroids<nClusters
    nReps = 10;
    randInd = randi(nPix, (nClusters-nCentroids)*nReps, 1);
    randStartPoints = cutVecs(randInd, :);
    randStartPoints = reshape(randStartPoints', [], (nClusters-nCentroids), nReps);
    randStartPoints = permute(randStartPoints, [2, 1, 3]);
    startCent = cat(1, repmat(startCent, 1, 1, nReps), randStartPoints);
end

[clusterIndex, clusterCentroid] = ...
    kmeans(real(cutVecs), nClusters, 'Distance', 'cityblock', 'MaxIter', 1e2, ...
    'start', startCent);