function processCurrentAcq(ajp)
% Performs all processing of currently loaded acquisition.

if ajp.debug
    ajp.log('Skipping all processing because debug mode is on.');
    return
end

% Motion correction:
try
    ajp.log('Started motion correction.');
    ajp.currentAcq.motionCorrect([],[],ajp.nameFunc);
catch err
    msg = sprintf('Motion correction aborted with error: %s', err.message);
    ajp.log(msg);
    printStack(ajp, err.stack);
    return % If motion correction fails, then no further processing can happen.
end

% Save binary movie file:
try
    ajp.log('Started creation of binary movie file.');
    ajp.currentAcq.indexMovie;
catch err
    msg = sprintf('Creation of binary movie file aborted with error: %s', err.message);
    ajp.log(msg);
    printStack(ajp, err.stack);
end

% Caclulate pixel covariance:
try
    ajp.log('Started pixel covariance calculation.');
    ajp.currentAcq.calcPxCovMJLM;
catch err
    msg = sprintf('Pixel covariance calculation aborted with error: %s', err.message);
    ajp.log(msg);
    printStack(ajp, err.stack);
end

% Save updated acq2p object:
try 
    ajp.log('Saving updated Acq2P object.');
    % Anonymous function allows us to determine the name of the saved
    % variable independently of the current workspace, while being more
    % transparent than eval():
    saveAcq = @(acq, p, f) save(fullfile(p, f), 'acq');
    saveAcq(ajp.currentAcq, ajp.currentAcq.defaultDir, [ajp.currentAcq.acqName, '_acq']); 
catch err
    msg = sprintf('Saving aborted with error: %s', err.message);
    ajp.log(msg);
    printStack(ajp, err.stack);
end

% Move acqFile to done folder:
if ~exist(ajp.dir.done, 'dir');
    mkdir(ajp.dir.done);
end
movefile(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),...
         fullfile(ajp.dir.done, ajp.currentAcqFileName));
     
ajp.log('Done processing.');

function printStack(ajp, stack)
% Prints the whole error stack to log file:
for ii = 1:numel(stack)
    msg = sprintf('ERROR\t%d\t%s', stack(ii).line, stack(ii).file);
    ajp.log(msg);
end

