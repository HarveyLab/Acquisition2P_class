function calcRoi(sel)
%Helper function that performs clustering using n simultaneous normcuts and
%updates cluster/ROI display accordingly

clusterNum = sel.disp.clusterNum;

%Perform kmeans clustering on n smallest cuts
clusterIndex = kmeans(sel.disp.cutVecs(:,1:clusterNum), clusterNum+1, 'Replicates', 10);

%Display current clustering results
sel.disp.currentClustering = reshape(clusterIndex, sel.roiInfo.covFile.nh, sel.roiInfo.covFile.nh);
set(sel.h.img.cluster, 'cdata', label2rgb(sel.disp.currentClustering));
title(sel.h.ax.cluster, sprintf('Clustering with % 1.0f cuts', clusterNum))

% Display cost of finest cut:
distMat = sel.getCovData;
cut = @(mask) sum(sum(distMat(mask(:), ~mask(:))));
assoc = @(mask) sum(sum(distMat(mask, :)));
ncut = @(mask) (cut(mask)/assoc(mask))+(cut(mask)/assoc(~mask));
fprintf('Cost of finest ncut: corr: %1.5f', ncut(sel.disp.currentClustering==clusterNum+1));

% Using cov: 
distMat = corrcov(distMat, 1);
cut = @(mask) sum(sum(distMat(mask(:), ~mask(:))));
assoc = @(mask) sum(sum(distMat(mask, :)));
ncut = @(mask) (cut(mask)/assoc(mask))+(cut(mask)/assoc(~mask));
fprintf(' cov: %1.5f', ncut(sel.disp.currentClustering==clusterNum+1));

% Average:
avgNcut = zeros(clusterNum+1, 1);
for i = 1:clusterNum+1
    avgNcut(i) = ncut(sel.disp.currentClustering==i);
end
fprintf(' avgcut: %1.5f\n', mean(avgNcut));

%Autoselect cluster at click position and display
sel.disp.currentClustInd = sel.disp.currentClustering(round(end/2)); % Finds center pixel of square array.
title(sel.h.ax.roi, 'ROI Selection');
sel.displayRoi
end
