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

%Autoselect cluster at click position and display
sel.disp.currentClustInd = sel.disp.currentClustering(round(end/2)); % Finds center pixel of square array.
title(sel.h.ax.roi, 'ROI Selection');
sel.displayRoi
end
