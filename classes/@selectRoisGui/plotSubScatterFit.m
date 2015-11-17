function plotSubScatterFit(sel)

% Delete old line if applicable
if isfield(sel.disp,'subFitLine') && isvalid(sel.disp.subFitLine)
    delete(sel.disp.subFitLine),
end

% Plot fit line
%xRange = [min(sel.disp.fNeuropil), max(sel.disp.fNeuropil)] - median(sel.disp.fNeuropil);
xRange = [min(sel.disp.fNeuropil), max(sel.disp.fNeuropil)]-sel.disp.f0Neuropil;
yRange = xRange.*sel.disp.neuropilCoef(2) + sel.disp.neuropilCoef(1);
sel.disp.subFitLine = line(xRange,yRange,'color','k','linewidth',2,'Parent',sel.h.ax.subSlope);
axis(sel.h.ax.subSlope,'tight'),
%set(sel.h.ax.subSlope, 'dataaspect', [1/3 1 1]); % It is important that a standard aspect ratio is kept, for visual comparability.