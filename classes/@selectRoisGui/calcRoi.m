function calcRoi(sel)
%Helper function that performs clustering using n simultaneous normcuts and
%updates cluster/ROI display accordingly

clusterNum = sel.disp.clusterNum;
clusterMod = sel.disp.clusterMod;

%Perform kmeans clustering on n smallest cuts
[clusterIndex, clusterCentroid] = kmeans(sel.disp.cutVecs(:,1:clusterNum), clusterMod+clusterNum+1,...
    'Distance','cityblock','Replicates', 10, 'maxIter', 1e2);
clusterQual = mean(silhouette(sel.disp.cutVecs(:,1:clusterNum),clusterIndex,'cityblock'));
sel.disp.centroidNorm = sqrt(sum(clusterCentroid.^2,2));

%Display current clustering results
sel.disp.currentClustering = reshape(clusterIndex, sel.roiInfo.covFile.nh, sel.roiInfo.covFile.nh);
set(sel.h.img.cluster, 'cdata', label2rgb(sel.disp.currentClustering));
title(sel.h.ax.cluster, ...
    sprintf('%1.0f cuts and %1.0f clusters: %0.3f',...
    clusterNum, clusterMod+1+clusterNum, clusterQual ))

%Autoselect cluster at click position and display
sel.disp.currentClustInd = sel.disp.currentClustering(round(end/2)); % Finds center pixel of square array.
title(sel.h.ax.roi, 'ROI Selection');
sel.displayRoi
end