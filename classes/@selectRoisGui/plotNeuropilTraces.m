function plotNeuropilTraces(sel, bodyInd, neuropilInd, isIndInNhCoords)

if ~exist('isIndInNhCoords','var') || isempty(isIndInNhCoords)
    isIndInNhCoords = true;
end

%Load cell body and neuropil fluorescence
mov = sel.movMap.Data.mov;
if isIndInNhCoords %if currently in neighborhood coord
    movIndBody = sel.nh2movInd(bodyInd);
    movIndNeuropil = sel.nh2movInd(neuropilInd);
else
    movIndBody = bodyInd;
    movIndNeuropil = neuropilInd;
end

sel.disp.fBody = mean(mov(:, sel.acq.mat2binInd(movIndBody)), 2)';
sel.disp.fNeuropil = mean(mov(:, sel.acq.mat2binInd(movIndNeuropil)), 2)';

% Remove excluded frames (removing them seems to be the most
% acceptable solution, since many functions below don't deal well
% with nans, and interpolation might skew results):
sel.disp.fBody(sel.disp.excludeFrames) = [];
sel.disp.fNeuropil(sel.disp.excludeFrames) = [];

% Remove bleaching:
% sel.disp.fBody = deBleach(sel.disp.fBody, 'runningAvg',9001);
% sel.disp.fNeuropil = deBleach(sel.disp.fNeuropil, 'runningAvg',9001);
sel.disp.fBody = deBleach(sel.disp.fBody, 'linear');
sel.disp.fNeuropil = deBleach(sel.disp.fNeuropil, 'linear');
sel.disp.f0Body = prctile(sel.disp.fBody,10);

% Smooth traces:
smoothWin = gausswin(sel.disp.smoothWindow)/sum(gausswin(sel.disp.smoothWindow));
sel.disp.fBody = conv(sel.disp.fBody, smoothWin, 'valid');
sel.disp.fNeuropil = conv(sel.disp.fNeuropil, smoothWin, 'valid');

%Extract subtractive coefficient btw cell + neuropil and plot
traceSubSelection = sel.disp.fBody < median(sel.disp.fBody)+mad(sel.disp.fBody)*2;
sel.disp.neuropilCoef = robustfit(sel.disp.fNeuropil(:)-median(sel.disp.fNeuropil),...
    sel.disp.fBody(:)-median(sel.disp.fBody),...
    'bisquare',4);

% Plot neuropil subtraction info:
plot(sel.disp.fNeuropil-median(sel.disp.fNeuropil), sel.disp.fBody-median(sel.disp.fBody),...
    '.', 'markersize', 3, 'Parent', sel.h.ax.subSlope)
plotSubScatterFit(sel)
title(sel.h.ax.subSlope, sprintf('Fitted subtractive coefficient is: %0.3f',...
    sel.disp.neuropilCoef(2)))

% Plot subtracted Trace
doSubTracePlot(sel),
title(sel.h.ax.roi, 'This pairing loaded');

% Focus back to main:
figure(sel.h.fig.main);
