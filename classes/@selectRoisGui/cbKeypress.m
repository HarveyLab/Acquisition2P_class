function cbKeypress(sel, ~, evt)
%Allows interactive selection / manipulation of ROIs. Possibly keypresses:
% 'tab' - Cycles through selection of each cluster in seed region as current ROI.
% 'f' - loads fluorescence trace for currently selected ROI, can be iteratively called to display multiple traces within single seed region
% 'space' - selects current ROI as cell body or neuropil, depending on state, and displays evaluative plots
% '1'-'9' - Selects current ROI or pairing and assigns it to group 1-9
% 'backspace' - (delete key) Deletes most recently selected ROI or pairing
% 'm' - Initiates manual ROI selection, via drawing a polygon over the main reference image. This manual ROI is then stored as a new 'cluster'
switch evt.Key
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
        
    case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}
        % cRoi is the unique number that the current ROI will get. It is
        % not stored globally but always determined locally from the
        % roiInfo structure such that it's always up to date:
        
        saveNewROI(sel,evt);
        
    case 'f'
        doAllClusterTraces(sel),        
    case 'space'
        %Determine if selection is new cell body or paired neuropil
        isNeuropilSelection = strcmp('Select neuropil pairing', get(get(sel.h.ax.roi, 'Title'), 'string'));
        
        if ~isNeuropilSelection
            %Get indices of current ROI as cell body + update title state
            sel.disp.indBody = find(sel.disp.roiMask);
            title(sel.h.ax.roi, 'Select neuropil pairing');
            [~,sel.disp.currentClustInd] = min(sel.disp.centroidNorm);
            
            % For upcoming neuropil selection, switch to largest cut,
            % because that's probably the neuropil:
%             clustStats = regionprops(sel.disp.currentClustering, 'BoundingBox');
%             boundingBoxCoords = reshape([clustStats.BoundingBox], 2, 2, []);
%             boundingBoxSize = abs(diff(boundingBoxCoords, [], 2));
%             boundingBoxArea = squeeze(prod(boundingBoxSize, 1));
%             boundingBoxArea(sel.disp.currentClustering(sel.disp.indBody(1))) = 0; % Exclude the cluster that was just selected as ROI body.
%             [~, sel.disp.currentClustInd] = max(boundingBoxArea);
            
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
%         figure(sel.h.fig.main)
        setfocus(sel.h.ax.roi);
        
    case {'add', 'equal'}
        %zoom in
        zoom(sel.h.ax.overview, 1.5);
        
    case {'hyphen','subtract'}
        %zoom out
        zoom(sel.h.ax.overview, 0.5);
end
end