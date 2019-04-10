function success = loadNextAcq(ajp)
% Checks if there are new unprocessed acq2ps in the to-be-processed folder.

acqFileList = dir(fullfile(ajp.dir.jobs, '*.mat'));

% Go to next un-done job:
if isempty(acqFileList)
    success = false;
    return
end
ajp.currentAcqFileName = acqFileList(1).name;
nextFilePath = fullfile(ajp.dir.jobs, ajp.currentAcqFileName);

% Rename file to prevent access by other job processor instance:
% (Use fast java renaming function.)
randId = num2str(randi(1e10));
tempFileName = [randId, '_', ajp.currentAcqFileName];
nextFilePathTemp = fullfile(ajp.dir.jobs, tempFileName);
java.io.File(nextFilePath).renameTo(java.io.File(nextFilePathTemp));

% Move acq file to inProgress directory:
if ~exist(ajp.dir.inProgress, 'dir')
    mkdir(ajp.dir.inProgress);
end
nextFilePathTempInProgress = fullfile(ajp.dir.inProgress, tempFileName);
movefile(nextFilePathTemp, nextFilePathTempInProgress);

% Rename back to normal name:
nextFilePath = fullfile(ajp.dir.inProgress, ajp.currentAcqFileName);
java.io.File(nextFilePathTempInProgress).renameTo(java.io.File(nextFilePath));

% Load next acquisition:
acq = load(nextFilePath); % Load into structure in case variable has weird name.
name = fieldnames(acq);
ajp.currentAcq = acq.(name{1});

% Log information:
msg = sprintf('Loaded acq2p for processing and moved file to "inProgress" folder: %s', nextFilePath);
ajp.log(msg);

success = true;
