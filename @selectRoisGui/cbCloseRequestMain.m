function cbCloseRequestMain(sel, ~, ~)
% Close request function for main window. Closes secondary windows as well.

% Delete timers:
timerNames = fieldnames(sel.h.timers);
for t = timerNames(:)'
    delete(sel.h.timers.(t{:}));
end

% Delete figures:
if ishandle(sel.h.fig.trace)
    delete(sel.h.fig.trace)
end

delete(sel.h.fig.main)