function saveNewROI(sel,evt)

%saves new roi

if isempty([sel.roiInfo.roi.id])
    newRoiNum = 1;
else
    newRoiNum = max([sel.roiInfo.roi.id])+1;
end

% Save current ROI:
newInd = numel([sel.roiInfo.roi.id])+1; % Attention: newRoiIndex is no necessarily the same as the roiNumber of the current ROI!
sel.roiInfo.roi(newInd).id = newRoiNum;
sel.roiInfo.roi(newInd).group = str2double(evt.Key);

% Check to see if a pairing has just been loaded
selectStatus = strcmp('This pairing loaded', get(get(sel.h.ax.roi, 'Title'), 'string'));

if ~selectStatus || isempty(sel.disp.indBody) || isempty(sel.disp.indNeuropil)
    % Save information for currently selected ROI group
    sel.roiInfo.roi(newInd).indBody = sel.nh2movInd(find(sel.disp.roiMask)); %#ok<FNDSB>
    newTitle = 'ROI Saved';
else
    % Save information for recently selected pairing
    sel.roiInfo.roi(newInd).indBody = sel.nh2movInd(sel.disp.indBody);
    sel.roiInfo.roi(newInd).indNeuropil = sel.nh2movInd(sel.disp.indNeuropil);
    sel.roiInfo.roi(newInd).subCoef = sel.disp.neuropilCoef(2);
    newTitle = 'Cell-Neuropil Pairing Saved';
    
    % Save backup file in case user forgets to save or matlab crashes:
    roiInfoBackup = struct;
    roiInfoBackup.hasBeenViewed = sel.roiInfo.hasBeenViewed;
    roiInfoBackup.roi = sel.roiInfo.roi; %#ok<STRNU>
    save(fullfile(sel.acq.defaultDir, 'cellSelectionBackup'), 'roiInfoBackup');
    
    % Set cluster to be equal to the one after the just selected
    % cell body, rather than the neuropil, so that we can continue
    % with the next one fluidly:
    sel.disp.currentClustInd = sel.disp.currentClustering(sel.disp.indBody(1))+1;
end

% Update roilabels and display.
sel.disp.roiLabels(sel.roiInfo.roi(newInd).indBody) = newRoiNum;
title(sel.h.ax.roi, sprintf('%s: #%03.0f', newTitle, newRoiNum));

%save and update display
sel.displayRoi;
sel.updateOverviewDisplay(false);