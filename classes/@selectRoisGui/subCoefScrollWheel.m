function subCoefScrollWheel(sel, ~, evt)
%Allows interactive adjustment of neuropil subtractive coefficient


switch sign(evt.VerticalScrollCount)
    case -1 % Scrolling up
        sel.disp.neuropilCoef(2) = sel.disp.neuropilCoef(2) + .01;
    case 1 % Scrolling down
        sel.disp.neuropilCoef(2) = sel.disp.neuropilCoef(2) - .01;
end

plotSubScatterFit(sel),
title(sel.h.ax.subSlope, sprintf('Adjusted subtractive coefficient is: %0.3f',...
    sel.disp.neuropilCoef(2)))

xRange = xlim(sel.h.ax.traceSub);
yRange = ylim(sel.h.ax.traceSub);
doSubTracePlot(sel),
xlim(sel.h.ax.traceSub,xRange),
ylim(sel.h.ax.traceSub,yRange),

end

