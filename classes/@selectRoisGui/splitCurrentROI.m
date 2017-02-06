function splitCurrentROI(sel)

% Get Covariance Data for normCuts
[covMat, pxNeighbors] = sel.getCovData;
corrMat = corrcov(covMat, 1);
m = size(corrMat, 1);
offDiags = diag2full(ones(m, 4), [-sqrt(m) -1 1 sqrt(m)], m, m); % 4-connected
nhWeight = 0;
W = corrMat + nhWeight*offDiags;

% Select subset of W matrix corresponding to selected cluster
clusterInd = find(sel.disp.currentClustering == sel.disp.currentClustInd);
W = W(clusterInd,clusterInd);

% do normCuts
D = diag(sum(W));
nEigs = 2;
[eVec,eVal] = eigs((D-W),D,nEigs,-1e-10);
[~,eigOrder] = sort(diag(eVal));

% split into two clusters
subClusterInd = kmeans(eVec(:,eigOrder(2)),2);
largeCluster = mode(subClusterInd);

% Update Current Clustering Indices
maxClusterInd = max(sel.disp.currentClustering(:));
subClusterInd(subClusterInd~=largeCluster) = maxClusterInd+1;
subClusterInd(subClusterInd==largeCluster) = sel.disp.currentClustInd;
sel.disp.currentClustering(clusterInd) = subClusterInd;

% Update Displays
set(sel.h.img.cluster, 'cdata', label2rgb(sel.disp.currentClustering));
title(sel.h.ax.cluster, ...
    sprintf('Cluster %1.0f split',sel.disp.currentClustInd)),
sel.displayRoi,