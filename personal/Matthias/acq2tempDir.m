function acq2tempDir(acq, dirTemp)
% Switch the paths pointing to the pixcov and bin files to the local temp
% dir.

acq.defaultDir = dirTemp;

[~, covFileName, ext] = fileparts(acq.roiInfo.slice.covFile.fileName);
acq.roiInfo.slice.covFile.fileName = fullfile(dirTemp, [covFileName, ext]);

[~, binMovName, ext] = fileparts(acq.indexedMovie.slice.channel(1).fileName);
acq.indexedMovie.slice.channel(1).fileName = fullfile(dirTemp, [binMovName, ext]);