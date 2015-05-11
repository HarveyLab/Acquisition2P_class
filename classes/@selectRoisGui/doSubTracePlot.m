function doSubTracePlot(sel,~,~)

if ~isfield(sel.disp,'fBody')
    return;
end

% Calculate corrected dF and plot
dF = sel.disp.fBody-sel.disp.fNeuropil*sel.disp.neuropilCoef(2);
dF = dF/sel.disp.f0Body;
dF = dF - median(dF);

movSizes = [sel.acq.correctedMovies.slice.channel.size];
nFramesComplete = sum(movSizes(:, 3));
includeFrames = setdiff(1:nFramesComplete, sel.disp.excludeFrames);
t = (0:nFramesComplete-1)*sel.disp.framePeriod;

% Plot raw dF if requested
if get(sel.h.ui.plotRaw,'Value') == 1
    dF_raw = sel.disp.fBody/sel.disp.f0Body;
    dF_raw = dF_raw-median(dF_raw);
    plot(t, addExcludedFrames(dF_raw), 'linewidth', 1, 'color', [0.6314 0.7255 1.0000], 'Parent', sel.h.ax.traceSub)
    hold(sel.h.ax.traceSub,'on')
end

plot(t, addExcludedFrames(dF), 'linewidth', 1,'color',[0.8500 0.3250 0.0980], 'Parent', sel.h.ax.traceSub)
hold(sel.h.ax.traceSub,'off')

title(sel.h.ax.traceSub, 'Trace after neuropil subtraction')

function trComplete = addExcludedFrames(tr)
    % Correct for removal of frames during 'valid' convolution for
    % smoothing:
    trPad = zeros(1, numel(tr)+sel.disp.smoothWindow-1);
    trPad(floor(sel.disp.smoothWindow/2)+(1:numel(tr))) = tr;
    trComplete = nan(1, nFramesComplete);
    trComplete(includeFrames) = trPad;
end
end