function processCurrentAcq(ajp)
% Performs all processing of currently loaded acquisition.

%create cleanup obj
cleanupObj = onCleanup(@() moveBackToUnproc(ajp));

if ajp.debug
    ajp.log('Skipping all processing because debug mode is on.');
    return
end

%figure out pixel neighborhood
neighborhoodConstant = 1.5;
if isfield(ajp.currentAcq.derivedData(1),'SIData')
    if isfield(ajp.currentAcq.derivedData(1).SIData,'SI4')
        objectiveMag = 25;
        zoomFac = ajp.currentAcq.derivedData(1).SIData.SI4.scanZoomFactor;
    elseif isfield(ajp.currentAcq.derivedData(1).SIData,'SI5')
        objectiveMag = 16;
        zoomFac = ajp.currentAcq.derivedData(1).SIData.SI5.zoomFactor;
    end
    pxCovRad = round(objectiveMag*zoomFac/neighborhoodConstant);
else
    pxCovRad = [];
end
    

% Motion correction:
%check if motion correction already applied
if isempty(ajp.currentAcq.shifts)
    try
        ajp.log('Started motion correction.');
        ajp.currentAcq.motionCorrect([],[],ajp.nameFunc);
    catch err
        msg = sprintf('Motion correction aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
        return % If motion correction fails, then no further processing can happen.
    end
else
    ajp.log('Motion correction already performed. Skipping...');
end

%save updated object
saveUpdatedObject(ajp);

% Save binary movie file:
%check if binary movie file created already
if isempty(ajp.currentAcq.indexedMovie)
    try
        ajp.log('Started creation of binary movie file.');
        ajp.currentAcq.indexMovie;
    catch err
        msg = sprintf('Creation of binary movie file aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('Binary movie already created. Skipping...');
end

%save updated object
saveUpdatedObject(ajp);

% Caclulate pixel covariance:
%check if pixel covariance already calculated
if isempty(ajp.currentAcq.roiInfo) || ajp.currentAcq.roiInfo.slice(1).covFile.nh ~= (2*pxCovRad + 1) %if no roi info or if different neighborhood
    try
        ajp.log('Started pixel covariance calculation.');
        ajp.currentAcq.calcPxCov([],pxCovRad);
    catch err
        msg = sprintf('Pixel covariance calculation aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('Covariance already calculated. Skipping...');
end

%save updated object
saveUpdatedObject(ajp);

% Move acqFile to done folder:
if ~exist(ajp.dir.done, 'dir');
    mkdir(ajp.dir.done);
end
movefile(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),...
    fullfile(ajp.dir.done, ajp.currentAcqFileName));

ajp.log('Done processing.');

end

function printStack(ajp, stack)
% Prints the whole error stack to log file:
for ii = 1:numel(stack)
    msg = sprintf('ERROR\t%d\t%s', stack(ii).line, stack(ii).file);
    ajp.log(msg);
end
end

function saveUpdatedObject(ajp)

% Save updated acq2p object:
try
    ajp.log('Saving updated Acq2P object.');
    eval(sprintf('%s=ajp.currentAcq;',ajp.currentAcq.acqName));
    save(sprintf('%s%s%s_acq.mat',ajp.currentAcq.defaultDir,filesep,...
        ajp.currentAcq.acqName),ajp.currentAcq.acqName);
    save(sprintf('%s%s%s',ajp.dir.inProgress,filesep,...
        ajp.currentAcqFileName),ajp.currentAcq.acqName);
catch err
    msg = sprintf('Saving aborted with error: %s', err.message);
    ajp.log(msg);
    printStack(ajp, err.stack);
end
end

function moveBackToUnproc(ajp)
if exist(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),'file')
    movefile(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),...
        fullfile(ajp.dir.jobs, ajp.currentAcqFileName));
    msg = 'Exectuion terminated. File moved back to queue.';
    ajp.log(msg);    
end
end
