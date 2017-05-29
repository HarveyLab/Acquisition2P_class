function processCurrentAcq(ajp)
% Performs all processing of currently loaded acquisition.

%create cleanup obj
cleanupObj = onCleanup(@() moveBackToUnproc(ajp));

if ajp.debug
    ajp.log('Skipping all processing because debug mode is on.');
    return
end

% Ensure that default dir exists:
if ~exist(ajp.currentAcq.defaultDir, 'dir')
    mkdir(ajp.currentAcq.defaultDir);
    msg = sprintf('Created default directory: %s', ajp.currentAcq.defaultDir);
    ajp.log(msg);
end

% Motion correction:
%check if motion correction already applied
if isempty(ajp.currentAcq.shifts)
    try
	
        % If we're on Orchestra, start parallel pool with correct
        % settings:
        if isunix && ~isempty(gcp('nocreate'))
            ClusterInfo.setWallTime('36:00'); % 20 hour
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

% Perform NMF-based source extraction:
for nSlice = 1:length(ajp.currentAcq.correctedMovies.slice)
    if isempty(dir(fullfile(ajp.currentAcq.defaultDir, '*_patchResults*.mat'))) ||...
            isempty(ajp.currentAcq.roiInfo) || ...
            nSlice > length(ajp.currentAcq.roiInfo.slice)
        try
            ajp.log('Started NMF Source Extraction');
            
            % If we're on Orchestra, start parallel pool with correct
            % settings:
            if isunix && ~isempty(gcp('nocreate'))
                ClusterInfo.setWallTime('20:00');
                ClusterInfo.setMemUsage('12000')
                ClusterInfo.setQueueName('mpi')
                parpool(12)
            end
            
            ajp.currentAcq.extractSources(nSlice);
            update_temporal_components_fromTiff(ajp.currentAcq);
            ajp.saveCurrentAcq;
            
            % If we're on Orchestra, we should close the parallel pool to
            % reduce memory usage:
            if isunix
                poolobj = gcp('nocreate');
                delete(poolobj);
            end
            
        catch err
            msg = sprintf('NMF Source Extraction aborted with error: %s', err.message);
            ajp.log(msg);
            printStack(ajp, err.stack);
            return
        end
    else
        ajp.log('NMF Source Extraction already completed. Skipping...');
    end
end

% Perform NMF-source deconvolution:
if isempty(dir(fullfile(ajp.currentAcq.defaultDir, '*_deconvResults.mat')))
    try
        ajp.log('Started NMF-source deconvolution.');
        
        % If we're on Orchestra, start parallel pool with correct
        % settings:
        if isunix && ~isempty(gcp('nocreate'))
            ClusterInfo.setWallTime('20:00');
            ClusterInfo.setMemUsage('12000')
            ClusterInfo.setQueueName('mpi')
            parpool(12)
        end
        
        ajp.currentAcq.deconvNmf;
        ajp.saveCurrentAcq;
        
        % If we're on Orchestra, we should close the parallel pool to
        % reduce memory usage:
        if isunix
            poolobj = gcp('nocreate');
            delete(poolobj);
        end
    catch err
        msg = sprintf('NMF-source deconvolution aborted with error: %s', err.message);
        ajp.log(msg);
        printStack(ajp, err.stack);
    end
else
    ajp.log('NMF-source deconvolution already calculated. Skipping...');
end

% Move acqFile to done folder:
if ~exist(ajp.dir.done, 'dir')
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
