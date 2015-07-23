function doAllClusterTraces(sel)

% Tell user that we're loading the traces:
        title(sel.h.ax.roi, 'Loading Trace for Current ROI');
        drawnow
        
        % Get matrix of fluorescence traces for all clusters:
        mov = sel.movMap.Data.mov;
        F = zeros(sel.disp.clusterNum+1, size(mov, 1));
        for i = 1:max(sel.disp.currentClustering(:))
            nhInd = find(sel.disp.currentClustering==i);
            movInd = sel.nh2movInd(nhInd); %#ok<FNDSB>
            movInd = movInd(~isnan(movInd)); % If click was at the edge, missing values are nan.
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
        clut = jet(max(sel.disp.currentClustering(:)));
        hold(sel.h.ax.traceClusters,'on');
        set(sel.h.ax.traceClusters, 'ColorOrder', clut, 'ColorOrderIndex', 1);
        
        xFrames = sel.disp.framePeriod:sel.disp.framePeriod:sel.disp.framePeriod*size(dF,2);
        plot(xFrames,dF', 'linewidth', 1,'Parent',sel.h.ax.traceClusters);

        title(sel.h.ax.roi, 'This trace loaded');
        
        %add arrow to current cluster
%         delete(findall(sel.h.fig.trace(1), 'type', 'annotation')); % Delete old annotations.
%         [arrowXPos, arrowYPos] = ds2nfu(sel.h.ax.traceClusters, ...
%             max(xFrames), nanmean(dF(sel.disp.currentClustInd, end-1000:end))); %get y value of last point of current cluster
%         annotation(sel.h.fig.trace(1), 'arrow',...
%             [1.03*arrowXPos 1.01*arrowXPos], repmat(arrowYPos,1,2)); %create arrow
        
        % reset neuroPil index, to prevent accidental saving of previous pairing
        sel.disp.indNeuropil = [];
        set(sel.h.ax.traceClusters, 'Color', [0.2 0.2 0.2]); %set color to gray
        
        figure(sel.h.fig.trace(1)) % Bring traces figure to front if it's hidden.
        drawnow
        figure(sel.h.fig.main) % Focus back on main figure.