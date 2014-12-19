function cbCloseRequestMain(sel, ~, ~)
% Close request function for main window. Closes secondary windows as well.

% Delete timers:
timerNames = fieldnames(sel.h.timers);
for t = timerNames(:)'
    delete(sel.h.timers.(t{:}));
end

% Delete figures:
if ishandle(sel.h.fig.trace(1))
    set(sel.h.fig.trace,'WindowStyle','normal');
    drawnow,
    for nWin = 1:4
        delete(sel.h.fig.trace(nWin)),
    end
end

delete(sel.h.fig.main)