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
fBody = mean(mov(:, sel.acq.mat2binInd(movIndBody)), 2)';


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