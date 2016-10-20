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
	
        % If we're on Orchestra, start parallel pool with correct
        % settings:
        if isunix && ~isempty(gcp('nocreate'))
            ClusterInfo.setWallTime('20:00'); % 20 hour
            ClusterInfo.setMemUsage('4000')
            ClusterInfo.setQueueName('mpi')
            parpool(12)
        end
	
        ajp.log('Started motion correction.');
        ajp.currentAcq.motionCorrect([],[],ajp.nameFunc);
        ajp.saveCurrentAcq;
        
        % If we're on Orchestra, we should close the parallel pool to
        % reduce memory usage:
        if isunix
            poolobj = gcp('nocreate');
            delete(poolobj);
        end
        
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
        for nSlice = 1:length(ajp.currentAcq.correctedMovies.slice)
            ajp.currentAcq.indexMovie(nSlice);
        end
        ajp.saveCurrentAcq;
    catch err
        msg = sprintf('Creation of binary movie file aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('Binary movie already created. Skipping...');
end

% Save NMF source extraction:
if isempty(ajp.currentAcq.roiInfo)
    try
        ajp.log('Started NMF Source Extraction');
        for nSlice = 1:length(ajp.currentAcq.correctedMovies.slice)
            ajp.currentAcq.extractSources(nSlice);
        end
        ajp.saveCurrentAcq;
    catch err
        msg = sprintf('NMF Source Extraction aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('NMF Source Extraction already completed. Skipping...');
end
    
    
% Caclulate pixel covariance:
%check if pixel covariance already calculated
% if isempty(ajp.currentAcq.roiInfo) ...
%         || (~isempty(pxCovRad) && ajp.currentAcq.roiInfo.slice(1).covFile.nh ~= (2*pxCovRad + 1))
%     % ROI info does not exist or a different neighborhood size was
%     % requested:
%     try
%         ajp.log('Started pixel covariance calculation.');
%         
%         % If we're on Orchestra, start parallel pool with correct
%         % settings:
%         if isunix && ~isempty(gcp('nocreate'))
%             ClusterInfo.setWallTime('20:00'); % 20 hour
%             ClusterInfo.setMemUsage('4000')
%             ClusterInfo.setQueueName('mpi')
%             parpool(12)
%         end
%         
%         ajp.currentAcq.calcPxCov([],pxCovRad);
%         ajp.saveCurrentAcq;
%         
%         % If we're on Orchestra, we should close the parallel pool to
%         % reduce memory usage:
%         if isunix
%             poolobj = gcp('nocreate');
%             delete(poolobj);
%         end
%     catch err
%         msg = sprintf('Pixel covariance calculation aborted with error: %s', err.message);
%         ajp.log(msg);
%         printStack(ajp, err.stack);
%     end
% else
%     ajp.log('Covariance already calculated. Skipping...');
% end

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

function moveBackToUnproc(ajp)
%get error information
errInfo = lasterror; %#ok<LERR>
if isempty(errInfo.identifier)
    moveDest = fullfile(ajp.dir.jobs, ajp.currentAcqFileName);
else
    moveDest = fullfile(ajp.dir.error, ajp.currentAcqFileName);
end

if exist(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),'file')
    if ~exist(ajp.dir.error, 'dir');
        mkdir(ajp.dir.error);
    end
    movefile(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName),...
        moveDest);
    msg = 'Exectuion terminated. Moved file to error folder.';
    ajp.log(msg);    
end
end
