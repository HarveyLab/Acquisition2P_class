function run(ajp)
% Runs a loop that loads acquisition objects and processes them.

while ~ajp.flagStop
    success = ajp.loadNextAcq;
    
    if ~success
        fprintf('%s: There are no unprocessed acquisitions. Waiting...\n', ...
            datestr(now, 'yymmdd HH:MM:SS'));
        pause(60);
        continue
    end
    
    ajp.processCurrentAcq;
end