function success = loadNextAcq(ajp)
% Checks if there are new unprocessed acq2ps in the to-be-processed folder.

acqFileList = dir(fullfile(ajp.dir.jobs, '*.mat'));

% Go to next un-done job:
if isempty(acqFileList)
    success = false;
    return
end
ajp.currentAcqFileName = acqFileList(1).name;
nextAcqFile = fullfile(ajp.dir.jobs, ajp.currentAcqFileName);

% Load next acquisition:
acq = load(nextAcqFile); % Load into structure in case variable has weird name.
name = fieldnames(acq);
ajp.currentAcq = acq.(name{1});

% Move acq file right away to inProgress directory:
if ~exist(ajp.dir.inProgress, 'dir');
    mkdir(ajp.dir.inProgress);
end
movefile(nextAcqFile, fullfile(ajp.dir.inProgress, ajp.currentAcqFileName));

% Log information:
msg = sprintf('Loaded acq2p for processing and moved file to "inProgress" folder: %s', nextAcqFile);
ajp.log(msg);

success = true;
