function run(ajp, shouldContinue)
% Runs a loop that loads acquisition objects and processes them.

if ~exist('shouldContinue', 'var') || isempty(shouldContinue)
    shouldContinue = true;
end

while ~ajp.flagStop
    success = ajp.loadNextAcq;
    
    if ~success && shouldContinue
        fprintf('%s: There are no unprocessed acquisitions. Waiting...\n', ...
            datestr(now, 'yymmdd HH:MM:SS'));
        pause(60);
        continue
    elseif ~success && ~shouldContinue
        ajp.stop
        break
    end
    
    ajp.processCurrentAcq;
end