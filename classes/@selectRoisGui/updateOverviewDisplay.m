function updateOverviewDisplay(sel, redrawAllRois)
%Helper function that updates the reference image with current ROI labels

if ~exist('redrawAllRois', 'var') || isempty(redrawAllRois)
    redrawAllRois = true;
end

% % Redraw image if slider is used:
% if isfield(sel.h.ui,'sliderBlack') % Slider is not implemented in portrait format figure...maybe change.
%     img = sel.disp.img;
%     img = mat2gray(img, [get(sel.h.ui.sliderBlack, 'Value'), get(sel.h.ui.sliderWhite, 'Value')]);
%     set(sel.h.img.overview, 'cdata', img);
% end

% Set transparency
roiTransp = 0.4;

% Turn hold on
hold(sel.h.ax.overview,'on');

% Display which areas have been viewed already:
if size(sel.disp.img, 3) == 3
    % Overview image is colored: Only show hasbeenviewed-outlines:
    beenViewedTransp = 0.35;
    set(sel.h.img.hasBeenViewed, 'AlphaData', bwperim(beenViewedTransp*sel.roiInfo.hasBeenViewed));
else
    beenViewedTransp = 0.2;
    set(sel.h.img.hasBeenViewed, 'AlphaData', beenViewedTransp*sel.roiInfo.hasBeenViewed);
end
    
% The patch vector has one element for each ROI ID up to the maximum ID,
% even if not all IDs are used. This is for easy indexing.
nPatches = max([sel.roiInfo.roi.id]);

if isempty(nPatches)
    return;
end

if redrawAllRois
    %delete current objects
    if isfield(sel.h.ui, 'roiPatches')
        delete(sel.h.ui.roiPatches(ishandle(sel.h.ui.roiPatches)));
    end
    
    %initialize patch array
    if ~isfield(sel.h.ui, 'roiPatches') && verLessThan('matlab', '8.4') %if older than 2014b
        sel.h.ui.roiPatches = nan(1, nPatches);
    else
        sel.h.ui.roiPatches = gobjects(1, nPatches);
    end
else
    if isfield(sel.h.ui,'roiPatches') 
        % Only new ROI is drawn: extend patch array accordingly:
        lastExistingPatch = find(ishandle(sel.h.ui.roiPatches), 1, 'last');
    else
        lastExistingPatch = 0;
    end
    if verLessThan('matlab', '8.4') %if older than 2014b
        sel.h.ui.roiPatches(lastExistingPatch+1:nPatches) = nan;
    else
        sel.h.ui.roiPatches(lastExistingPatch+1:nPatches) = gobjects;
    end
end

% Loop through each potential patch and draw it if necessary. Recall that
% the patch array goes from 1 to max(roiId) and has valid handles in
% exactly those elements that do not need to be drawn:
isExistingRoi = ishandle(sel.h.ui.roiPatches);
for roiId = 1:nPatches

    % Don't re-draw existing patches:
    if isExistingRoi(roiId)
        continue
    end
    
    % Don't draw patches for non-exising ROIs:
    if ~ismember(roiId, [sel.roiInfo.roi.id])
        continue
    end
    
    % Don't draw patches for ROIs that have no pixels in them (that
    % sometimes happens for some reason...maybe investigate):
    if isempty(sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId).indBody)
        continue
    end
    
    % Get mask for ROI to be drawn:
    currRoiMask = sel.disp.roiLabels == roiId;
    
    % Don't draw patches for ROIs that have no pixels:
    if nnz(currRoiMask)==0
        continue
    end

    %find edges of current roi
    [rowInd,colInd] = sel.findEdges(currRoiMask);
    
    % Write roiId:
    [rowIndAll, colIndAll] = find(currRoiMask); % Use all points to find more natural center, downweighting fine processes.
    text(mean(colIndAll), mean(rowIndAll), num2str(roiId), ...
        'verticalalignment', 'middle', 'horizontalalignment', 'center', ...
        'color', 'w', 'fontsize', 8, 'parent', sel.h.ax.overview)
    
    %create patch object
    roiGroup = sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId).group;
    sel.h.ui.roiPatches(roiId) = patch(rowInd, colInd,...
        sel.disp.roiColors(roiGroup, :),...
        'Parent', sel.h.ax.overview);
    set(sel.h.ui.roiPatches(roiId), 'FaceAlpha', roiTransp);
    
    %create context menu
    hMenu = uicontextmenu('Parent', sel.h.fig.main);
    uimenu(hMenu, 'Label', sprintf('Delete ROI %d', roiId),...
        'Callback', {@sel.cbDeleteRoi, roiId});
    labelParent = uimenu(hMenu, 'Label', 'Change Label');
    for labelInd = 1:9
        uimenu(labelParent, 'Label', num2str(labelInd), 'Callback', {@sel.cbChangeRoiLabel, roiId, labelInd});
    end
    uimenu(hMenu, 'Label', 'Show Trace Data', 'Callback', {@sel.cbShowROITrace, roiId});
    set(sel.h.ui.roiPatches(roiId), 'UIContextMenu', hMenu)
end

end