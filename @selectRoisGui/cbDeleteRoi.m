function cbDeleteRoi(sel, ~, ~, roiInd)
% Delete all references to ROI:
sel.roiInfo.roiLabels(sel.roiInfo.roiLabels == roiInd) = 0;
sel.roiInfo.roiList(sel.roiInfo.roiList == roiInd) = [];
% sel.roiInfo.roi(roiInd) = [];
sel.roiInfo.grouping(roiInd) = NaN;

% Update Display
title(sel.h.ax.roi, sprintf('ROI %d deleted', roiInd));

%delete roi
delete(sel.h.ui.roiPatches(roiInd));
if verLessThan('matlab', '8.4') %if older than 2014b
    sel.h.ui.roiPatches(roiInd) = 0;
else
    sel.h.ui.roiPatches(roiInd) = gobjects(1);
end
% sel.updateOverviewDisplay;
end