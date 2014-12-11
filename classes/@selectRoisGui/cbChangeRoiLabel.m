function cbChangeRoiLabel(sel, ~, ~, roiId)

%get newLabel
options.Resize = 'on';
options.WindowStyle = 'normal';
newLabel = inputdlg('Provide new label',...
    sprintf('Select new label for roi %d',roiId),1,{''},options);
newLabel = str2double(newLabel);

%error check
if isempty(newLabel) || isnan(newLabel) || newLabel<1 || newLabel>9
    return;
end

%change group label
oldLabel = sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId).group;
sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId).group = newLabel;

%Update Display
title(sel.h.ax.roi, sprintf('Changed label for ROI %d from %d to %d',...
    roiId, oldLabel, newLabel));
set(sel.h.ui.roiPatches(roiId), 'FaceColor', sel.disp.roiColors(newLabel,:));
end