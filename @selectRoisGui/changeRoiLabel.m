function changeRoiLabel(sel, ~, ~, roiInd)

%get newLabel
options.Resize = 'on';
options.WindowStyle = 'normal';
newLabel = inputdlg('Provide new label',...
    sprintf('Select new label for roi %d',roiInd),1,{''},options);
newLabel = str2double(newLabel);

%error check
if isempty(newLabel) || isnan(newLabel)
    return;
end

%change grouping label
oldLabel = sel.roiInfo.grouping(roiInd);
sel.roiInfo.grouping(roiInd) = newLabel;

%save
sel.acq.roiInfo.slice(sel.sliceNum) = orderfields(sel.roiInfo,...
    sel.acq.roiInfo.slice(sel.sliceNum));

%Update Display
sel.roiTitle = title(sel.hAxROI, sprintf('Changed label for ROI %d from %d to %d',...
    roiInd,oldLabel,newLabel));
set(sel.roiPlotH(roiInd),'FaceColor',sel.roiColors(newLabel,:));
set(sel.h.fig.main, 'userdata', sel);
end