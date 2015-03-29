function x = estimateNumberOfCuts(sel, corrMat)
% estimateNumberOfCuts(sel, corrMat) finds a reasonable number of cuts. The
% algorithm looks at the nearest neighbors of each pixel in
% correlation-space. If, for any cluster, most of the nearest neighbors of
% its pixels are in a different cluster, then this is considered an
% over-clustering and the ideal number of clusters is less than the
% current. All this is done in a low-dimensional embedding of the
% correlation space (using isomap MDS), because that seems to work better
% than working directly in the space of the full correlation matrix.

% Get 2-D MDS of correlation matrix:
x = isomap(1-corrMat, 2);

% Calculate new weight matrix based on MDS:
W = squareform(pdist(x));
W = max(W(:))-W; % Invert, because small distance means high weight
W(1:sqrt(end)+1:end) = 0; % Ignore self-distance.

% Only keep nearest neighbors (we're not interested in far-away points, but
% basically want to know how much a cluster overlaps with another):
[~, nnIndRow] = max(W, [], 1);
[~, nnIndCol] = max(W, [], 2);
Wnn = zeros(size(W));
nnIndRow = sub2ind(size(W), nnIndRow, 1:numel(nnIndRow));
Wnn(nnIndRow) = W(nnIndRow);
nnIndCol = sub2ind(size(W), nnIndCol', 1:numel(nnIndCol));
Wnn(nnIndCol) = W(nnIndCol);

for clusterNum = 2:12
    % Perform clustering:
    clustering = kmeans(sel.disp.cutVecs(:,1:clusterNum), clusterNum+1, 'Replicates', 10);

    % For each cluster, get normcut of cutting that cluster from the rest:
    cutCost = zeros(clusterNum, 1);
    for i = 1:clusterNum
        A = clustering==i;
        cutCost(i) = cut(Wnn, A, ~A)/assoc(Wnn, A, A<inf);
    end
    
    % cutCost threshold:
    % This is somewhat arbitrary. 0.5 works and makes intuitive sense: if a
    % cut costs more than half its association value, then you can't really
    % call it a separate cluster.
    cutCostThreshold = 0.5;

    isTooManyCuts = any(cutCost>cutCostThreshold);
    if isTooManyCuts
        break
    end
    
end

sel.disp.clusterNum = clusterNum-1;