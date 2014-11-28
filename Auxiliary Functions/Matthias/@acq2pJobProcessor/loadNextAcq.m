function success = loadNextAcq(ajp)
% Checks if there are new unprocessed acq2ps in the to-be-processed folder.

acqFileList = dir(fullfile(ajp.jobDir, '*.mat'));

% Go to next un-done job:
if isempty(acqFileList)
    success = false;
    return
end
nextAcqFile = fullfile(ajp.jobDir, acqFileList(1).name);

% Load next acquisition:
acq = load(nextAcqFile); % Load into structure in case variable has weird name.
name = fieldnames(acq);
ajp.currentAcq = acq.(name{1});

% Move acq file right away:
dirProgress = fullfile(ajp.jobDir, 'in progress');
if ~exist(dirProgress, 'dir');
    mkdir(dirProgress);
end
movefile(nextAcqFile, fullfile(dirProgress, acqFileList(1).name));

% Log information:
msg = sprintf('Loaded acq2p for processing and moved file to "done" folder: %s.\n', nextAcqFile);
ajp.log(msg);

success = true;
