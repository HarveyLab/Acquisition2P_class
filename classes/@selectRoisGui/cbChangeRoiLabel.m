function cbChangeRoiLabel(sel, ~, ~, roiId, newLabel)

%change group label
oldLabel = sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId).group;
sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId).group = newLabel;

%Update Display
title(sel.h.ax.roi, sprintf('Changed label for ROI %d from %d to %d',...
    roiId, oldLabel, newLabel));
set(sel.h.ui.roiPatches(roiId), 'FaceColor', sel.disp.roiColors(newLabel,:));
end