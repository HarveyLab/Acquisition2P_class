function cbDeleteRoi(sel, ~, ~, roiInd)
% Delete all references to ROI:
sel.roiInfo.roiLabels(sel.roiInfo.roiLabels == roiInd) = 0;
sel.roiInfo.roiList(sel.roiInfo.roiList == roiInd) = [];
sel.roiInfo.roi(roiInd) = [];
sel.roiInfo.grouping(roiInd) = 0;

% Update Display
title(sel.h.ax.roi, sprintf('ROI %d deleted', roiInd));
sel.updateOverviewDisplay;
end