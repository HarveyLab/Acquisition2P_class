function doSubTracePlot(sel)

% Calculate corrected dF and plot
dF = sel.disp.fBody-sel.disp.fNeuropil*sel.disp.neuropilCoef(2);
dF = dF/sel.disp.f0Body;
dF = dF - median(dF);
xFrames = sel.disp.framePeriod:sel.disp.framePeriod:sel.disp.framePeriod*length(dF);

% Plot raw dF if requested
if get(sel.h.ui.plotRaw,'Value') == 1
    dF_raw = sel.disp.fBody/sel.disp.f0Body;
    dF_raw = dF_raw-median(dF_raw);
    plot(xFrames, dF_raw, 'linewidth', 1, 'color', [0 0.4470 0.7410], 'Parent', sel.h.ax.traceSub)
    hold(sel.h.ax.traceSub,'on')
end

plot(xFrames, dF, 'linewidth', 1,'color',[0.8500 0.3250 0.0980], 'Parent', sel.h.ax.traceSub)
hold(sel.h.ax.traceSub,'off')

title(sel.h.ax.traceSub, 'Trace after neuropil subtraction')