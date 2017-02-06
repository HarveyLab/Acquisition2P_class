function cbKeypress(sel, ~, evt)
%Allows interactive selection / manipulation of ROIs. Possibly keypresses:
% 'tab' - Cycles through selection of each cluster in seed region as current ROI.
% 'f' - loads fluorescence trace for currently selected ROI, can be iteratively called to display multiple traces within single seed region
% 'space' - selects current ROI as cell body or neuropil, depending on state, and displays evaluative plots
% '1'-'9' - Selects current ROI or pairing and assigns it to group 1-9
% 'backspace' - (delete key) Deletes most recently selected ROI or pairing
% 'm' - Initiates manual ROI selection, via drawing a polygon over the main reference image. This manual ROI is then stored as a new 'cluster'
switch evt.Key
    case 'z' % Merge Current Cluster
        mergeCurrentROI(sel),
    case 'x' % Split Current Cluster
        splitCurrentROI(sel),
    case 'p' % Play movie of current region:
        mov = sel.movMap.Data.mov;
        nh = sel.roiInfo.covFile.nh;
        nhInd = 1:nh^2;
        movInd = sel.nh2movInd(nhInd);
        movHere = mov(:, sel.acq.mat2binInd(movInd))';
        movHere = reshape(movHere, nh, nh, []);
        clear mov
        playMov(movHere)
    case 't'
        addOverlayTrace(sel),
    case 'c'
        cla(sel.h.ax.traceOverlay);
    case 'n'
        figure(sel.h.fig.trace(4));
    case 'm'
        doManualROI(sel),
    case 'backspace'
        if numel(sel.roiInfo.roi)==0
            return
        end
        lastRoiId = sel.roiInfo.roi(end).id;
        sel.cbDeleteRoi([], [], lastRoiId)
        
    case 'escape'
        title(sel.h.ax.roi, 'ROI selection');
        
    case {'1', '2', '3', '4', '5', '6', '7', '8', '9', 'r'}
        % Make button for group 9 that is easier to reach than the "9" key
        % (R = "rubbish"):
        if evt.Key == 'r'
            clear evt
            evt.Key = '9';
        end
        saveNewROI(sel,evt);
        
    case 'f'
        doAllClusterTraces(sel)
        
    case 'space'
        % If we have a pairing loaded, then space shouldn't do anything.
        % Only selecting the ROI, clicking in a new spot, pressing tab or
        % pressing escape should abort this pairing.
        if strcmp('This pairing loaded', get(get(sel.h.ax.roi, 'Title'), 'string'));
            return
        end
        
        %Determine if selection is new cell body or paired neuropil
        isNeuropilSelection = strcmp('Select neuropil pairing', get(get(sel.h.ax.roi, 'Title'), 'string'));
        
        if ~isNeuropilSelection
            sel.disp.indBody = find(sel.disp.roiMask);
            
            % Check if the new ROI would completely swallow an existing
            % ROI (This creates problems with the roiLabels matrix. If we
            % need to allow one ROI overlapping another completely, then we
            % need to replace roiLabels with a more complex solution):
            roiIdsInLocationOfNewRoi = unique(sel.disp.roiLabels(sel.disp.indBody));
            roiIdsOutsideLocOfNewRoi = unique(sel.disp.roiLabels(setdiff(1:numel(sel.disp.roiLabels), sel.disp.indBody)));
            roiIdsInsideThatAreNotOutside = setdiff(roiIdsInLocationOfNewRoi, roiIdsOutsideLocOfNewRoi);
            if ~isempty(roiIdsInsideThatAreNotOutside)
                title(sel.h.ax.roi, 'NEW ROI COMPLETELY OVERLAPS EXISTING ONE. REVISE SELECTION.');
                return
            end
                
            % Update title state
            title(sel.h.ax.roi, 'Select neuropil pairing');
            
            % Advance to next cluster (but only if we're not using the
            % mouse to choose clusters):
            if ~sel.disp.isMouseOnRoiAx
                centroidNorm = sel.disp.centroidNorm;
                centroidNorm(sel.disp.currentClustInd) = inf; % Make sure that the chosen cluster is not the same as the cell body cluster.
                [~,sel.disp.currentClustInd] = min(centroidNorm);
            end
            
            %Update ROI display
            sel.displayRoi;
            
        elseif isNeuropilSelection
            title(sel.h.ax.roi, 'Loading Trace for cell-neuropil pairing');
            drawnow
            
            %Get indices of current ROI as paired neuropil
            sel.disp.indNeuropil = find(sel.disp.roiMask);
            
            sel.plotNeuropilTraces(sel.disp.indBody, sel.disp.indNeuropil);
        end
        
    case 'tab'
        nClust = max(sel.disp.currentClustering(:));
        if isempty(evt.Modifier) || ~any(strcmpi(evt.Modifier,'shift'))
            %Increase currently selected cluster by 1
            sel.disp.currentClustInd = mod(sel.disp.currentClustInd, nClust)+1;
        else
            %if shift pressed as well, go backwards
            sel.disp.currentClustInd = sel.disp.currentClustInd-1;
            
            %Wrap around
            if sel.disp.currentClustInd == 0
                sel.disp.currentClustInd = nClust;
            end
        end
        
        %Update ROI display
        sel.displayRoi
        setfocus(sel.h.ax.overview);
    case {'add', 'equal'}
        %zoom in
        zoom(sel.h.ax.overview, 1.5);
        
    case {'hyphen','subtract'}
        %zoom out
        zoom(sel.h.ax.overview, 0.5);
end
end