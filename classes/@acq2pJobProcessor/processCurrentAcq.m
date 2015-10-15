function processCurrentAcq(ajp)
% Performs all processing of currently loaded acquisition.

%create cleanup obj
cleanupObj = onCleanup(@() cleanUpFun(ajp));

if ajp.debug
    ajp.log('Skipping all processing because debug mode is on.');
    return
end

%figure out pixel neighborhood
neighborhoodConstant = 1.5;
if isprop(ajp.currentAcq,'derivedData') && ~isempty(ajp.currentAcq.derivedData)...
        && isfield(ajp.currentAcq.derivedData(1),'SIData')
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
        ajp.saveCurrentAcq;
    catch err
        msg = sprintf('Motion correction aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
        return % If motion correction fails, then no further processing can happen.
    end
else
    ajp.log('Motion correction already performed. Skipping...');
end

% Save binary movie file:
%check if binary movie file created already
if isempty(ajp.currentAcq.indexedMovie)
    try
        ajp.log('Started creation of binary movie file.');
        ajp.currentAcq.indexMovie;
        ajp.saveCurrentAcq;
    catch err
        msg = sprintf('Creation of binary movie file aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('Binary movie already created. Skipping...');
end

% Caclulate pixel covariance:
% Check if pixel covariance already calculated
if isempty(ajp.currentAcq.roiInfo) ...
        || (~isempty(pxCovRad) && ajp.currentAcq.roiInfo.slice(1).covFile.nh ~= (2*pxCovRad + 1))
    % ROI info does not exist or a different neighborhood size was
    % requested:
    try
        ajp.log('Started pixel covariance calculation.');
        ajp.currentAcq.calcPxCov([],pxCovRad);
        ajp.saveCurrentAcq;
    catch err
        msg = sprintf('Pixel covariance calculation aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('Covariance already calculated. Skipping...');
end

% Move files to remote directory:
% We infer from the raw movie paths if the movies should uploaded to a
% remote directory.
if ~isempty(strfind(ajp.currentAcq.Movies{1}, 'research.files.med.harvard.edu')) ...
        && isempty(strfind(ajp.currentAcq.correctedMovies.slice(1).channel(1).fileName{1}, 'research.files.med.harvard.edu'))
    % The raw movies are on the server, but the corrected ones are not:
    % --> Move corrected files to server.
    
    [dirRemoteRaw, ~, ~] = fileparts(ajp.currentAcq.Movies{1});
    dirRemoteProcessed = strrep(dirRemoteRaw, '\raw\', '\processed\');
    mkdir(dirRemoteProcessed);
    
    % Copy from local default dir to remote processed dir (using robocopy
    % in the background):
    % l - log only, don't actually copy.
    % Z - resume if network connection lost.
    % np - don't print % progress to console.
    % xo - exclude older files.
    % xd temp - exclude directories named "temp"
    % & - run command in background.
    % r - number of retries.
    % s - copy subdirectories
    copyCommand = 'robocopy %s %s /s /R:0 /Z /NP /log:%s & exit &';

    % Copy local to server:
    source = ajp.currentAcq.defaultDir;
    destination = dirRemoteProcessed;
    logFileName = fullfile(dirRemoteProcessed, 'robocopyLocalToServerLog.txt');
    system(sprintf(copyCommand, source, destination, logFileName));
    
    ajp.log('Started robocopy to copy from local to remote "processed" directory.');
end
    

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

function cleanUpFun(ajp)
%get error information
errInfo = lasterror; %#ok<LERR>

if isempty(errInfo.identifier)
    moveDest = fullfile(ajp.dir.jobs, ajp.currentAcqFileName);
    movefile(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName), moveDest);
    msg = 'Exectuion terminated. Found no error, so assuming manual abort. Moving job file back to "to do" directory.';
    ajp.log(msg);
    return
else
    moveDest = fullfile(ajp.dir.error, ajp.currentAcqFileName);
end

if exist(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),'file')
    if ~exist(ajp.dir.error, 'dir');
        mkdir(ajp.dir.error);
    end
    movefile(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName), moveDest);
    msg = 'Exectuion terminated. Moved file to error folder.';
    ajp.log(msg);    
end
end
