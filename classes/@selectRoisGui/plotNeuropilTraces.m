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
sel.disp.fBody = deBleach(sel.disp.fBody, 'exp_linear');
sel.disp.fNeuropil = deBleach(sel.disp.fNeuropil, 'exp_linear');
sel.disp.f0Body = prctile(sel.disp.fBody,10);

% Smooth traces:
smoothWin = gausswin(sel.disp.smoothWindow)/sum(gausswin(sel.disp.smoothWindow));
sel.disp.fBody = conv(sel.disp.fBody, smoothWin, 'valid');
sel.disp.fNeuropil = conv(sel.disp.fNeuropil, smoothWin, 'valid');

%Extract subtractive coefficient btw cell + neuropil and plot
cutoffFreq = 60; %Cutoff frequency in seconds
a = sel.disp.framePeriod / cutoffFreq;
fBodyHighpass = filtfilt([1-a a-1],[1 a-1], sel.disp.fBody);
fNeuropilHighpass = filtfilt([1-a a-1],[1 a-1], sel.disp.fNeuropil);

df = smooth(abs(diff(fBodyHighpass)), round(2/sel.disp.framePeriod));
isFChanging = df>2*mode(round(df*100)/100);

traceSubSelection = ~isFChanging;

sel.disp.neuropilCoef = robustfit(fNeuropilHighpass(traceSubSelection),...
    fBodyHighpass(traceSubSelection),...
    'bisquare',4);

% Plot neuropil subtraction info:
plot(fNeuropilHighpass(~traceSubSelection), fBodyHighpass(~traceSubSelection),...
    '.', 'markersize', 3, 'Parent', sel.h.ax.subSlope),
hold(sel.h.ax.subSlope,'on'),
plot(fNeuropilHighpass(traceSubSelection), fBodyHighpass(traceSubSelection),...
    '.', 'markersize', 3, 'Parent', sel.h.ax.subSlope),
hold(sel.h.ax.subSlope,'off'),
plotSubScatterFit(sel)
title(sel.h.ax.subSlope, sprintf('Fitted subtractive coefficient is: %0.3f      (%.2f excluded)',...
    sel.disp.neuropilCoef(2), mean(isFChanging))),

% Plot subtracted Trace
doSubTracePlot(sel),
title(sel.h.ax.roi, 'This pairing loaded');

% Focus back to main:
figure(sel.h.fig.main);