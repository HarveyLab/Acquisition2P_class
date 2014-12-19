function cbKeypressTraceWin(sel, ~, evt)
%Allows for keypresses from the traces figures

switch evt.Key
    case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}
        % cRoi is the unique number that the current ROI will get. It is
        % not stored globally but always determined locally from the
        % roiInfo structure such that it's always up to date:
        
        saveNewROI(sel,evt);
        
        %restore focus to original window
        setfocus(sel.h.ax.roi);
    case 'c'
        cla(sel.h.ax.traceOverlay);
end