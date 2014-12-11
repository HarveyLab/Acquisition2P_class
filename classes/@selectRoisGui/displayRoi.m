function displayRoi(sel)
%Helper function which updates display of currently selected ROI in overlay
%panel

%Check current status, reflected in title of ROI overlay axes. If trace has
%recently been loaded, reset title to ROI selection, or if currently
%searching for neuropil, do not enforce ROI continuity constraint
enforceContinuity = 1;
% enforceContinuity = 0; % Continuity is not always desired when selecting small axon/dendrite rois.

currentTitle = get(get(sel.h.ax.roi, 'Title'), 'String');
if strcmp(currentTitle,'This trace loaded') || strcmp(currentTitle,'This pairing loaded')
    currentTitle = 'ROI Selection';
elseif strcmp(currentTitle,'Select neuropil pairing')
    enforceContinuity = 0;
end

%Get mask corresponding to currently selected cluster, and optionally
%enforce that only the largest connected component of cluster is selected
roiMask = sel.disp.currentClustering == sel.disp.currentClustInd;
if enforceContinuity == 1
    CC = bwconncomp(roiMask);
    numPix = cellfun(@numel, CC.PixelIdxList);
    [~, bigROI] = max(numPix);
    roiMask = false(size(roiMask));
    roiMask(CC.PixelIdxList{bigROI}) = true;
end
sel.disp.roiMask = roiMask;

% Grab appropriate region around clicked pixel. interp2 takes care of edge
% cases.
margin = round((sel.roiInfo.covFile.nh-1)/2); % NH is constrained to be of the form 2*a+1 when the covMat is originally calculated. We round just in case.
relInd = -margin:margin;
roiCenter = round(sel.disp.currentPos);
[roiRegionX, roiRegionY] = meshgrid(roiCenter(2)+relInd, roiCenter(1)+relInd);
roiImg = interp2(sel.disp.img, roiRegionX, roiRegionY, 'nearest', nan);

% Grab same region from roiLabels to display previously selected rois:
roiLabels = interp2(sel.disp.roiLabels, roiRegionX, roiRegionY, 'nearest', nan);


% Scale image:
roiImg = imadjust(mat2gray(roiImg));
roiImg = max(0.3, roiImg); % Make dark areas brighter so that colors are more easily visible.

% Overlay mask and image
% (Existing ROIs = green, potential new ROI = yellow, overlap = red.
old = roiLabels;
new = sel.disp.roiMask;
roiOverlay(:,:,1) = 1.0*(new & ~old) + 0.0*(~new & old) + 1.0*(new & old) + 1.0*(~new & ~old);
roiOverlay(:,:,2) = 0.6*(new & ~old) + 1.0*(~new & old) + 0.0*(new & old) + 1.0*(~new & ~old);
roiOverlay(:,:,3) = 0.0*(new & ~old) + 0.0*(~new & old) + 0.0*(new & old) + 1.0*(~new & ~old);
roiImg = repmat(roiImg, [1 1 3]);
roiImg = roiImg .* roiOverlay;

set(sel.h.img.roi, 'cdata', roiImg);
title(sel.h.ax.roi, currentTitle);

%show current patches in roi selection panel
% neighborhoodLabels = sel.roiInfo.roiLabels(roiCenter(2) - displayWidth + iOffS:...
%     roiCenter(2) + displayWidth - iOffE,...
%     roiCenter(1) - displayWidth + jOffS:...
%     roiCenter(1) + displayWidth - jOffE); %get subset of labels that match neighborhood
% uniqueLabels = unique(neighborhoodLabels(:)); %get unique labels
% uniqueLabels = uniqueLabels(uniqueLabels~=0); %remove zero label
% 
% if isfield(sel,'roiSelectPatchH') && any(ishandle(sel.roiSelectPatchH))
%     delete(sel.roiSelectPatchH(ishandle(roiSelectPatchH)));
% end
% 
% if ~isfield(sel,'roiSelectPatchH') && verLessThan('matlab', '8.4') %if older than 2014b
%     sel.roiSelectPatchH = zeros(1,length(uniqueLabels));
% elseif ~isfield(sel,'roiSelectPatchH')
%     sel.roiSelectPatchH = gobjects(1,length(uniqueLabels));
% end
% hold(sel.h.ax.roi,'on');
% for labelInd = uniqueLabels' %for each label
%     %get current roi
%     currROI = sel.roiInfo.roiLabels == labelInd;
%     
%     %find edges of current roi
%     [rowInd,colInd] = findEdges(currROI);
%     
%     %create patch object
%     sel.roiSelectPatchH(ismember(uniqueLabels,labelInd)) = ...
%         patch(rowInd, colInd, 'k','FaceAlpha',0,...
%         'EdgeColor','k','Parent', sel.h.ax.roi);
% end
% hold(sel.h.ax.roi,'off');

end