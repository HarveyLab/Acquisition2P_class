function cbDeleteRoi(sel, ~, ~, roiId)
% Delete ROI:
sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId) = [];

% Update display
title(sel.h.ax.roi, sprintf('ROI %d deleted', roiId));

% Delete ROI patch:
delete(sel.h.ui.roiPatches(roiId));
if verLessThan('matlab', '8.4') %if older than 2014b
    sel.h.ui.roiPatches(roiId) = nan;
else
    sel.h.ui.roiPatches(roiId) = gobjects(1);
end
end