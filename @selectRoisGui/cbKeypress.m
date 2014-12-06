function cbKeypress(sel, ~, evt)
%Allows interactive selection / manipulation of ROIs. Possibly keypresses:
% 'tab' - Cycles through selection of each cluster in seed region as current ROI.
% 'f' - loads fluorescence trace for currently selected ROI, can be iteratively called to display multiple traces within single seed region
% 'space' - selects current ROI as cell body or neuropil, depending on state, and displays evaluative plots
% '1'-'9' - Selects current ROI or pairing and assigns it to grouping 1-9
% 'backspace' - (delete key) Deletes most recently selected ROI or pairing
% 'm' - Initiates manual ROI selection, via drawing a polygon over the main reference image. This manual ROI is then stored as a new 'cluster'
switch evt.Key
    case 'm'
        warning('this key still needs to be implemented')
        %         %Turn off figure click callback while drawing ROI
        %         set(sel.h.fig.main, 'WindowButtonDownFcn', []),
        %         sel.roiTitle = title(sel.h.ax.roi, 'Drawing Manual ROI');
        %         %If a poly somehow wasn't deleted, do it now
        %         if isfield(sel,'manualPoly') && isvalid(sel.manualPoly)
        %             delete(sel.manualPoly)
        %         end
        %         %Draw polygon on reference image, use mask to add new 'cluster'
        %         %to allClusters matrix, and select new cluster as current
        %         sel.manualPoly = impoly(sel.h.ax.ref);
        %         set(sel.h.fig.main, 'WindowButtonDownFcn', @cbMouseclick),
        %         manualMask = createMask(sel.manualPoly);
        %         newClusterNum = max(sel.disp.currentClustering(:))+1;
        %         sel.disp.currentClustering(manualMask) = newClusterNum;
        %         sel.disp.currentClustInd = newClusterNum;
        %         %Update cluster display
        %         displayWidth = ceil(sel.covFile.radiusPxCov+2);
        %         roiCenter = round(getPosition(sel.hROIpt));
        %         imshow(label2rgb(sel.disp.currentClustering),'Parent',sel.h.ax.cluster),
        %         axes(sel.h.ax.cluster),
        %         xlim([roiCenter(1)-displayWidth roiCenter(1)+displayWidth]),
        %         ylim([roiCenter(2)-displayWidth roiCenter(2)+displayWidth]),
        %         title(sel.h.ax.cluster, sprintf('Manual ROI over %01.0f cuts',newClusterNum-2)),
        %         %Delete interactive polygon and update title
        %         delete(sel.manualPoly),
        %         sel.roiTitle = title(sel.h.ax.roi, 'Displaying Manual ROI');
        %         %Update ROI display
        %         set(sel.h.fig.main, 'userdata', sel);
        %         displayROI(sel.h.fig.main),
        %         sel = get(keyPressObj, 'userdata');
        
    case 'backspace'    
        lastRoi = max(sel.roiInfo.roiList);
        if isempty(lastRoi)
            return
        end
        sel.cbDeleteRoi(lastRoi)
        
    case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}
        % cRoi is the unique number that the current ROI will get. It is
        % not stored globally but always determined locally from the
        % roiList such that it's always up to date:
        if isempty(sel.roiInfo.roiList)
            cRoi = 1;
        else
            cRoi = max(sel.roiInfo.roiList)+1;
        end
        
        sel.roiInfo.grouping(cRoi) = str2double(evt.Key);
        
        %Check to see if a pairing has just been loaded
        selectStatus = strcmp('This pairing loaded', get(get(sel.h.ax.roi, 'Title'), 'string'));
        
        if ~selectStatus || isempty(sel.disp.indBody) || isempty(sel.disp.indNeuropil)
            % Save information for currently selected ROI grouping
            sel.roiInfo.roi(cRoi).indBody = sel.nh2movInd(find(sel.disp.roiMask)); %#ok<FNDSB>
            newTitle = 'ROI Saved';
        else
            % Save information for recently selected pairing
            sel.roiInfo.roi(cRoi).indBody = sel.nh2movInd(sel.disp.indBody);
            sel.roiInfo.roi(cRoi).indNeuropil = sel.nh2movInd(sel.disp.indNeuropil);
            sel.roiInfo.roi(cRoi).subCoef = sel.disp.neuropilCoef(2);
            newTitle = 'Cell-Neuropil Pairing Saved';
            
            % Set cluster to be equal to the one after the just selected
            % cell body, rather than the neuropil, so that we can continue
            % with the next one fluidly:
            sel.disp.currentClustInd = sel.disp.currentClustering(sel.disp.indBody(1))+1;
        end
        
        % Update roilabels, list, display.
        sel.roiInfo.roiLabels(sel.roiInfo.roi(cRoi).indBody) = cRoi;
        sel.roiInfo.roiList = sort([sel.roiInfo.roiList; cRoi]);
        title(sel.h.ax.roi, sprintf('%s: #%03.0f', newTitle, cRoi));
        
        %save and update display
        sel.displayRoi;
        sel.updateOverviewDisplay;
        sel.h.ui.roiPoint.delete;
        
    case 'f'
        % Tell user that we're loading the traces:
        title(sel.h.ax.roi, 'Loading Trace for Current ROI');
        drawnow
        
        % Get matrix of fluorescence traces for all clusters:
        mov = sel.movMap.Data.mov;
        F = zeros(sel.disp.clusterNum+1, size(mov, 1));
        for i = 1:sel.disp.clusterNum+1
            nhInd = find(sel.disp.currentClustering==i);
            movInd = sel.nh2movInd(nhInd); %#ok<FNDSB>
            F(i,:) = mean(mov(:, sel.acq.mat2binInd(movInd)), 2)';
            F(i, sel.disp.excludeFrames) = nan;
        end
        
        % Normalize, smooth, and plot all traces
        dF = bsxfun(@rdivide, F, nanmedian(F, 2));
        smoothWin = gausswin(sel.disp.smoothWindow)/sum(gausswin(sel.disp.smoothWindow));
        for i = 1:size(dF,1)
            dF(i,:) = conv(dF(i,:)-1, smoothWin,'same');
        end
        
        dF = bsxfun(@plus, dF, 1*(size(dF, 1):-1:1)'); % Offset traces in y.
        
        % Coloring: use same hues as in the image showing the cuts:
        cla(sel.h.ax.traceClusters);
        clut = jet(sel.disp.clusterNum+1);
        hold(sel.h.ax.traceClusters,'on');
        set(sel.h.ax.traceClusters, 'ColorOrder', clut, 'ColorOrderIndex', 1);
        
        plot(dF', 'linewidth', 1,'Parent',sel.h.ax.traceClusters);
        
        
        
        title(sel.h.ax.roi, 'This trace loaded');
        
        %add arrow to current cluster
        delete(findall(sel.h.fig.trace, 'type', 'annotation')); % Delete old annotations.
        [arrowXPos, arrowYPos] = ds2nfu(sel.h.ax.traceClusters, ...
            size(dF,2), mean(dF(sel.disp.currentClustInd, end-1000:end))); %get y value of last point of current cluster
        annotation(sel.h.fig.trace, 'arrow',...
            [1.03*arrowXPos 1.01*arrowXPos], repmat(arrowYPos,1,2)); %create arrow
        
        % reset neuroPil index, to prevent accidental saving of previous pairing
        sel.disp.indNeuropil = [];
        set(sel.h.ax.traceClusters, 'Color', [0.2 0.2 0.2]); %set color to gray
        
        figure(sel.h.fig.trace) % Bring traces figure to front if it's hidden.
        drawnow
        figure(sel.h.fig.main) % Focus back on main figure.
        
    case 'space'
        %Determine if selection is new cell body or paired neuropil
        isNeuropilSelection = strcmp('Select neuropil pairing', get(get(sel.h.ax.roi, 'Title'), 'string'));
        
        if ~isNeuropilSelection
            %Get indices of current ROI as cell body + update title state
            sel.disp.indBody = find(sel.disp.roiMask);
            title(sel.h.ax.roi, 'Select neuropil pairing');
            
            % For upcoming neuropil selection, switch to largest cut,
            % because that's probably the neuropil:
            [~, clustSizeInd] = sort(histcounts(sel.disp.currentClustering(:)), 'descend');
            sel.disp.currentClustInd = clustSizeInd(1);
            
            %Update ROI display
            sel.displayRoi;
            
        elseif isNeuropilSelection
            title(sel.h.ax.roi, 'Loading Trace for cell-neuropil pairing');
            drawnow
            
            %Get indices of current ROI as paired neuropil
            sel.disp.indNeuropil = find(sel.disp.roiMask);
            
            %Load cell body and neuropil fluorescence
            mov = sel.movMap.Data.mov;
            movIndBody = sel.nh2movInd(sel.disp.indBody);
            fBody = mean(mov(:, sel.acq.mat2binInd(movIndBody)), 2)';
            
            movIndNeuropil = sel.nh2movInd(sel.disp.indNeuropil);
            fNeuropil = mean(mov(:, sel.acq.mat2binInd(movIndNeuropil)), 2)';
            
            % Remove excluded frames (removing them seems to be the most
            % acceptable solution, since many functions below don't deal well
            % with nans, and interpolation might skew results):
            fBody(sel.disp.excludeFrames) = [];
            fNeuropil(sel.disp.excludeFrames) = [];
            
            % Plot non-debleached traces:
            cla(sel.h.ax.traceDetrend);
            hold(sel.h.ax.traceDetrend, 'on');
            plot(sel.h.ax.traceDetrend, fNeuropil+100)
            plot(sel.h.ax.traceDetrend, fBody+100)
            
            % Remove bleaching:
            f0Body = prctile(fBody,10);
            fBody = deBleach(fBody, 'linear');
            fNeuropil = deBleach(fNeuropil, 'linear');
            
            % Smooth traces:
            smoothWin = gausswin(sel.disp.smoothWindow)/sum(gausswin(sel.disp.smoothWindow));
            fBody = conv(fBody, smoothWin, 'valid');
            fNeuropil = conv(fNeuropil, smoothWin, 'valid');
            
            %Extract subtractive coefficient btw cell + neuropil and plot
            traceSubSelection = fBody < median(fBody)+mad(fBody)*2;
            sel.disp.neuropilCoef = robustfit(fNeuropil(traceSubSelection)-median(fNeuropil),...
                fBody(traceSubSelection)-median(fBody),...
                'bisquare',4);
            
            % Plot neuropil subtraction info:
            plot(fNeuropil-median(fNeuropil), fBody-median(fBody),...
                '.', 'markersize', 3, 'Parent', sel.h.ax.subSlope)
            xRange = (min(fNeuropil):max(fNeuropil)) - median(fNeuropil);
            hold(sel.h.ax.subSlope,'on');
            plot(xRange, xRange*sel.disp.neuropilCoef(2) + sel.disp.neuropilCoef(1), ...
                'r', 'Parent', sel.h.ax.subSlope)
            hold(sel.h.ax.subSlope,'off');
            set(sel.h.ax.subSlope, 'dataaspect', [1/3 1 1]); % It is important that a standard aspect ratio is kept, for visual comparability.
            title(sel.h.ax.subSlope, sprintf('Fitted subtractive coefficient is: %0.3f',...
                sel.disp.neuropilCoef(2)))
            
            % Calculate corrected dF and plot
            dF = fBody-fNeuropil*sel.disp.neuropilCoef(2);
            dF = dF/f0Body;
            dF = dF - median(dF);
            plot(dF, 'linewidth', 1.5, 'Parent', sel.h.ax.traceSub)
            title(sel.h.ax.traceSub, 'Trace after neuropil subtraction')
            
            title(sel.h.ax.roi, 'This pairing loaded');
            
            % Also plot in detrend/nondetrend plot:
            plot(fNeuropil, 'Parent', sel.h.ax.traceDetrend);
            hold(sel.h.ax.traceDetrend, 'on');
            plot(fBody, 'Parent', sel.h.ax.traceDetrend);
            hold(sel.h.ax.traceDetrend, 'off');
            legend(sel.h.ax.traceDetrend, 'NP raw', 'Body raw', 'NP debleached', 'Body debleached');
            title(sel.h.ax.traceDetrend, 'Raw vs. debleached');
            
            % Focus back to main:
            figure(sel.h.fig.main);
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