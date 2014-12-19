function addOverlayTrace(sel)

thisROIind = sel.nh2movInd(find(sel.disp.roiMask));
mov = sel.movMap.Data.mov;
thisROItrace = mean(mov(:, sel.acq.mat2binInd(thisROIind)), 2)';
smoothWin = gausswin(sel.disp.smoothWindow)/sum(gausswin(sel.disp.smoothWindow));
thisROItrace = conv(thisROItrace,smoothWin, 'valid');
xFrames = sel.disp.framePeriod:sel.disp.framePeriod:sel.disp.framePeriod*length(thisROItrace);
plot(sel.h.ax.traceOverlay, xFrames, thisROItrace),
title(sel.h.ax.traceOverlay, 'Raw Trace Overlay'),



% % Plot non-debleached traces:
% cla(sel.h.ax.traceDetrend);
% hold(sel.h.ax.traceDetrend, 'on');
% plot(sel.h.ax.traceDetrend, sel.disp.fNeuropil+100)
% plot(sel.h.ax.traceDetrend, sel.disp.fBody+100)
% 
% % Also plot in detrend/nondetrend plot:
% plot(sel.disp.fNeuropil, 'Parent', sel.h.ax.traceDetrend);
% hold(sel.h.ax.traceDetrend, 'on');
% plot(sel.disp.fBody, 'Parent', sel.h.ax.traceDetrend);
% hold(sel.h.ax.traceDetrend, 'off');
% legend(sel.h.ax.traceDetrend, 'NP raw', 'Body raw', 'NP debleached', 'Body debleached');
% title(sel.h.ax.traceDetrend, 'Raw vs. debleached');