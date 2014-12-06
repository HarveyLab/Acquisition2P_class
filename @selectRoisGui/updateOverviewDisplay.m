function updateOverviewDisplay(sel, redrawRois)
%Helper function that updates the reference image with current ROI labels

if ~exist('redrawRois', 'var') || isempty(redrawRois)
    redrawRois = true;
end

% % Redraw image if slider is used:
% if isfield(sel.h.ui,'sliderBlack') % Slider is not implemented in portrait format figure...maybe change.
%     img = sel.disp.img;
%     img = mat2gray(img, [get(sel.h.ui.sliderBlack, 'Value'), get(sel.h.ui.sliderWhite, 'Value')]);
%     set(sel.h.img.overview, 'cdata', img);
% end

% Set transparency
beenViewedTransp = 0.15;
roiTransp = 0.4;

% Turn hold on
hold(sel.h.ax.overview,'on');

% Display which areas have been viewed already:
set(sel.h.img.hasBeenViewed, 'AlphaData', beenViewedTransp*sel.roiInfo.hasBeenViewed);

%get number of rois
nRoi = max(sel.roiInfo.roiList);

if redrawRois
    
    %delete current objects
    if isfield(sel.h.ui, 'roiPatches')
        delete(sel.h.ui.roiPatches(ishandle(sel.h.ui.roiPatches)));
    end
    
    %initialize patch array
    if ~isfield(sel.h.ui, 'roiPatches') && verLessThan('matlab', '8.4') %if older than 2014b
        sel.h.ui.roiPatches = zeros(1, nRoi);
    elseif ~isfield(sel,'roiPlotH')
        sel.h.ui.roiPatches = gobjects(1, nRoi);
    end
end
    
% If no rois to draw, abort:
if isempty(nRoi)
    return
end

%loop through each roi which has to be drawn
for roiInd = sel.roiInfo.roiList(:)'
    
    if roiInd <= length(sel.h.ui.roiPatches) && ishandle(sel.h.ui.roiPatches(roiInd)) %if object already exists
        continue; %skip
    end
    
    %get current roi
    currROI = sel.roiInfo.roiLabels == roiInd;
    
    %skip if empty roi
    if ~any(currROI(:))
        continue;
    end
    
    %find edges of current roi
    [rowInd,colInd] = sel.findEdges(currROI);
    
    %create patch object
    sel.h.ui.roiPatches(roiInd) = patch(rowInd, colInd,...
        sel.disp.roiColors(sel.roiInfo.grouping(roiInd), :),...
        'Parent', sel.h.ax.overview);
    set(sel.h.ui.roiPatches(roiInd), 'FaceAlpha', roiTransp);
    
    %create context menu
    hMenu = uicontextmenu('Parent', sel.h.fig.main);
    uimenu(hMenu, 'Label', sprintf('Delete ROI %d', roiInd),...
        'Callback', {@sel.cbDeleteRoi, roiInd});
    uimenu(hMenu, 'Label', 'Change Label', 'Callback', {@sel.cbChangeRoiLabel, roiInd});
    set(sel.h.ui.roiPatches(roiInd), 'UIContextMenu', hMenu)
end

end