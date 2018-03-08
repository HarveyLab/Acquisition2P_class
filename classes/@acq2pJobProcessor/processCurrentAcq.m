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
        if isunix
            % Shut down existing pool:
            delete(gcp('nocreate'));
            
            if verLessThan('matlab', '9.2') % Matlab < 2017a
                % NOTE that ClusterInfo settings are global for all jobs of an Orchestra user!
                % This means that there can be cross-talk between these settings. If another 
                % job changes them while this script here is in the process of starting the 
                % pool, the new settings might be used. To avoid this, make sure to start jobs
                % one at a time and wait until the parallel pool is started before staring the 
                % next job.
                ClusterInfo.setWallTime('36:00'); % 20 hour
                ClusterInfo.setMemUsage('4000')
                ClusterInfo.setQueueName('mpi')
            else
                % Newer versions use a different syntax (on O2). See https://wiki.rc.hms.harvard.edu:8443/display/O2/Matlab+Parallel+jobs+using+the+custom+O2+cluster+profile
                c = parcluster;
                c.AdditionalProperties.WallTime = '36:00:00';
                c.AdditionalProperties.QueueName = 'mpi';
                c.AdditionalProperties.AdditionalSubmitArgs = '--mem-per-cpu=4G';
                c.saveProfile
            end
            
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
            if isunix
                % Shut down existing pool:
                delete(gcp('nocreate'));
                if verLessThan('matlab', '9.2') % Matlab < 2017a
                    ClusterInfo.setWallTime('40:00'); % 20 hour
                    ClusterInfo.setMemUsage('12000')
                    ClusterInfo.setQueueName('mpi')
                else
                    % Newer versions use a different syntax (on O2). See https://wiki.rc.hms.harvard.edu:8443/display/O2/Matlab+Parallel+jobs+using+the+custom+O2+cluster+profile
                    c = parcluster;
                    c.AdditionalProperties.WallTime = '40:00:00';
                    c.AdditionalProperties.QueueName = 'mpi';
                    c.AdditionalProperties.AdditionalSubmitArgs = '--mem-per-cpu=12G';
                    c.saveProfile
                end
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
        if isunix
            % Shut down existing pool:
            delete(gcp('nocreate'));
            if verLessThan('matlab', '9.2') % Matlab < 2017a
                ClusterInfo.setWallTime('10:00'); % 20 hour
                ClusterInfo.setMemUsage('12000')
                ClusterInfo.setQueueName('mpi')
            else
                % Newer versions use a different syntax (on O2). See https://wiki.rc.hms.harvard.edu:8443/display/O2/Matlab+Parallel+jobs+using+the+custom+O2+cluster+profile
                c = parcluster;
                c.AdditionalProperties.WallTime = '10:00:00';
                c.AdditionalProperties.QueueName = 'mpi';
                c.AdditionalProperties.AdditionalSubmitArgs = '--mem-per-cpu=12G';
                c.saveProfile
            end
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
