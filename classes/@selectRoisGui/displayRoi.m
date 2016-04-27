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
roiMask = sel.disp.currentClustering == min(sel.disp.currentClustInd, max(sel.disp.currentClustering(:)));
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
roiImg = interp2(sel.disp.img(:,:,min(end, 2)), roiRegionX, roiRegionY, 'nearest', nan); % If img is RGB, pick green channel.

% Grab same region from roiLabels to display previously selected rois:
roiLabels = interp2(sel.disp.roiLabels, roiRegionX, roiRegionY, 'nearest', nan);

% Scale image:
roiImg = imadjust(mat2gray(roiImg));
roiImg = max(0.1, roiImg); % Make dark areas brighter so that colors are more easily visible.

% Overlay mask and image
% (Existing ROIs = green, potential new ROI = yellow, overlap = red.
old = roiLabels;
old(isnan(old)) = 0;
new = sel.disp.roiMask;
new(isnan(new)) = 0;
roiOverlay(:,:,1) = 1.0*(new & ~old) + 0.0*(~new & old) + 1.0*(new & old) + 1.0*(~new & ~old);
roiOverlay(:,:,2) = 0.6*(new & ~old) + 1.0*(~new & old) + 0.0*(new & old) + 1.0*(~new & ~old);
roiOverlay(:,:,3) = 0.0*(new & ~old) + 0.0*(~new & old) + 0.0*(new & old) + 1.0*(~new & ~old);
roiImg = repmat(roiImg, [1 1 3]);
roiImg = roiImg .* roiOverlay;

set(sel.h.img.roi, 'cdata', roiImg);
title(sel.h.ax.roi, currentTitle);

end