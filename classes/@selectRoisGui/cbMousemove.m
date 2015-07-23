function cbMousemove(sel, ~, ~)

% Find mouse coordinates in ROI axis:
axRoiBottomLeft = round(sel.h.ax.roi.Position(1:2).*sel.h.fig.main.Position(3:4));
currentPosInAx = sel.h.fig.main.CurrentPoint-axRoiBottomLeft;
axSizePix = sel.h.ax.roi.Position(3:4).*sel.h.fig.main.Position(3:4);

% Return if mouse is not over ROI axis:
if any(currentPosInAx<0) || any(currentPosInAx>axSizePix)
    sel.disp.isMouseOnRoiAx = false;
    return
end
sel.disp.isMouseOnRoiAx = true;

% Find neighborhood index of mouse position:
currentRelPosInAx = currentPosInAx./axSizePix;
nh = size(sel.disp.currentClustering, 1);
nhSub = ceil([(1-currentRelPosInAx(2))*nh, currentRelPosInAx(1)*nh]);

% If mouse is over a new cluster, switch to new cluster index:
if sel.disp.currentClustInd ~= sel.disp.currentClustering(nhSub(1), nhSub(2))
	sel.disp.currentClustInd = sel.disp.currentClustering(nhSub(1), nhSub(2));
    sel.displayRoi
end