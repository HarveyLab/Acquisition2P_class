function cbChangeRoiLabel(sel, ~, ~, roiInd)

%get newLabel
options.Resize = 'on';
options.WindowStyle = 'normal';
newLabel = inputdlg('Provide new label',...
    sprintf('Select new label for roi %d',roiInd),1,{''},options);
newLabel = str2double(newLabel);

%error check
if isempty(newLabel) || isnan(newLabel) || newLabel<1 || newLabel>9
    return;
end

%change grouping label
oldLabel = sel.roiInfo.grouping(roiInd);
sel.roiInfo.grouping(roiInd) = newLabel;

%Update Display
title(sel.h.ax.roi, sprintf('Changed label for ROI %d from %d to %d',...
    roiInd,oldLabel,newLabel));
set(sel.h.ui.roiPatches(roiInd),'FaceColor',sel.disp.roiColors(newLabel,:));
end