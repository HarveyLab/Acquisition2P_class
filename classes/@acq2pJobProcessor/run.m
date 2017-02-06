function run(ajp, isExitAfterOneJob)
% Runs a loop that loads acquisition objects and processes them.

if ~exist('isExitAfterOneJob', 'var') || isempty(isExitAfterOneJob)
    isExitAfterOneJob = true;
end

nJobsDone = 0;
while ~ajp.flagStop
    success = ajp.loadNextAcq;
    
    if ~success && ~isExitAfterOneJob
        fprintf('%s: There are no unprocessed acquisitions. Waiting...\n', ...
            datestr(now, 'yymmdd HH:MM:SS'));
        pause(60);
        continue
    elseif success && (~isExitAfterOneJob || nJobsDone==0)
        ajp.processCurrentAcq;
        nJobsDone = nJobsDone + 1;
    else
        ajp.stop
        break
    end
    
    if isExitAfterOneJob && nJobsDone>0
        break
    end
end