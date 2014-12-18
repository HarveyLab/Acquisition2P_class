function doSubTracePlot(sel)

% Calculate corrected dF and plot
dF = sel.disp.fBody-sel.disp.fNeuropil*sel.disp.neuropilCoef(2);
dF = dF/sel.disp.f0Body;
dF = dF - median(dF);
plot(dF, 'linewidth', 1.5, 'Parent', sel.h.ax.traceSub)
title(sel.h.ax.traceSub, 'Trace after neuropil subtraction')