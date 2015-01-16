function acqChangeDir(acq, newDir)
% acqChangeDir(acq, newDir)

% By default, only change pixCovFile and binary movie:

% pixCov:
[~, f, e] = fileparts(acq.roiInfo.slice(1).covFile.fileName);
acq.roiInfo.slice(1).covFile.fileName = fullfile(newDir, [f, e]);

% binary movie:
[~, f, e] = fileparts(acq.indexedMovie.slice(1).channel(1).fileName);
acq.indexedMovie.slice(1).channel(1).fileName = fullfile(newDir, [f, e]);