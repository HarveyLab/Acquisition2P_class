function doManualROI(sel)

%Turn off figure click callback while drawing ROI
set(sel.h.fig.main, 'WindowButtonDownFcn', []),
title(sel.h.ax.roi, 'Drawing Manual ROI');
%If a poly somehow wasn't deleted, do it now
if isfield(sel.disp,'manualPoly') && isvalid(sel.disp.manualPoly)
    delete(sel.disp.manualPoly)
end

%Draw polygon on reference image, restore click callback
sel.disp.manualPoly = impoly(sel.h.ax.overview);
set(sel.h.fig.main, 'WindowButtonDownFcn', @sel.cbMouseclick),
manualMask = createMask(sel.disp.manualPoly, sel.h.img.overview);
%Get neighborhood of click and convert mask to neighborhood format
margin = round((sel.roiInfo.covFile.nh-1)/2);
margInd = -margin:margin;
xInd = round(sel.disp.currentPos(2)) + margInd;
yInd = round(sel.disp.currentPos(1)) + margInd;
manualMask = manualMask(yInd,xInd);
%use mask to add new 'cluster' to allClusters matrix, and select new cluster as current
newClusterNum = max(sel.disp.currentClustering(:))+1;
sel.disp.currentClustering(manualMask) = newClusterNum;
sel.disp.currentClustInd = newClusterNum;

% %Update cluster display
% displayWidth = ceil(sel.covFile.radiusPxCov+2);
% roiCenter = round(getPosition(sel.hROIpt));
% imshow(label2rgb(sel.disp.currentClustering),'Parent',sel.h.ax.cluster),
% axes(sel.h.ax.cluster),
% xlim([roiCenter(1)-displayWidth roiCenter(1)+displayWidth]),
% ylim([roiCenter(2)-displayWidth roiCenter(2)+displayWidth]),

%Delete interactive polygon and update title
delete(sel.disp.manualPoly),
set(sel.h.img.cluster, 'cdata', label2rgb(sel.disp.currentClustering));
title(sel.h.ax.roi, 'Displaying Manual ROI');
title(sel.h.ax.cluster, sprintf('Manual ROI over %01.0f cuts',newClusterNum-2)),

%Update ROI display
displayRoi(sel),