function calcRoi(sel)
%Helper function that performs clustering using n simultaneous normcuts and
%updates cluster/ROI display accordingly

nCuts = sel.disp.clusterNum;
clusterMod = sel.disp.clusterMod;

[clusterIndex, clusterCentroid] = getClusters(sel, nCuts, nCuts+1+clusterMod);

clusterQual = mean(silhouette(sel.disp.cutVecs(:,1:nCuts),clusterIndex,'cityblock'));
sel.disp.centroidNorm = sqrt(sum(clusterCentroid.^2,2));

%Display current clustering results
sel.disp.currentClustering = reshape(clusterIndex, sel.roiInfo.covFile.nh, sel.roiInfo.covFile.nh);
set(sel.h.img.cluster, 'cdata', label2rgb(sel.disp.currentClustering));
title(sel.h.ax.cluster, ...
    sprintf('%1.0f:%1.0f cuts and %1.0f clusters: %0.3f',...
    1+sel.disp.cutMod_nTopToExclude, nCuts, clusterMod+1+nCuts, clusterQual ))

%Autoselect cluster at click position and display
sel.disp.currentClustInd = sel.disp.currentClustering(round(end/2)); % Finds center pixel of square array.
title(sel.h.ax.roi, 'ROI Selection');
sel.displayRoi
end