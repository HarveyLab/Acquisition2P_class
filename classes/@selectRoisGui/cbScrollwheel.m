function cbScrollwheel(sel, ~, evt)
%Allows interactive adjustment of the number of clusters / cuts to perform

% No region has been selected yet:
if isempty(sel.disp.cutVecs)
    return
end

%Determine scrolling direction and update cluster count accordingly
nEigs = size(sel.disp.cutVecs, 2);

if strcmpi(evt.Source.CurrentModifier,'control')
    switch sign(evt.VerticalScrollCount)
        case -1
            sel.disp.clusterMod = sel.disp.clusterMod+1;
        case 1
            if sel.disp.clusterMod+1+sel.disp.clusterNum >2
                sel.disp.clusterMod = sel.disp.clusterMod-1;
            else
                return
            end
    end
elseif strcmpi(evt.Source.CurrentModifier, 'shift')
    switch sign(evt.VerticalScrollCount)
        case -1
            sel.disp.cutMod_nTopToExclude = min(sel.disp.cutMod_nTopToExclude+1, sel.disp.clusterNum-1);
            sel.disp.clusterMod = sel.disp.clusterMod-1;
        case 1
            sel.disp.cutMod_nTopToExclude = max(sel.disp.cutMod_nTopToExclude-1, 0);
    end
else
    switch sign(evt.VerticalScrollCount)
        case -1 % Scrolling up
            if sel.disp.clusterNum < nEigs
                sel.disp.clusterNum = sel.disp.clusterNum + 1;
            else
                return
            end
        case 1 % Scrolling down
            if sel.disp.clusterNum > 1
                sel.disp.clusterNum = sel.disp.clusterNum - 1;
            else
                return
            end
    end
end
% Recalculate clusters with new cluster count:
sel.calcRoi;

%  Load Traces if requested
if get(sel.h.ui.autoLoadTraces,'Value') == 1 && strcmp(sel.h.timers.loadTraces.Running, 'off')
    start(sel.h.timers.loadTraces);
else
    stop(sel.h.timers.loadTraces);
end

end

