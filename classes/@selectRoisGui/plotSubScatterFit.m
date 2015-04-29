function plotSubScatterFit(sel)

% Delete old line if applicable
if isfield(sel.disp,'subFitLine') && isvalid(sel.disp.subFitLine)
    delete(sel.disp.subFitLine),
end

% Plot fit line
xRange = [min(sel.disp.fNeuropil), max(sel.disp.fNeuropil)] - median(sel.disp.fNeuropil);
yRange = xRange.*sel.disp.neuropilCoef(2) + sel.disp.neuropilCoef(1);
sel.disp.subFitLine = line(xRange,yRange,'color','r','Parent',sel.h.ax.subSlope);
%set(sel.h.ax.subSlope, 'dataaspect', [1/3 1 1]); % It is important that a standard aspect ratio is kept, for visual comparability.


