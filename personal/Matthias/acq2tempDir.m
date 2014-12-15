function acq2tempDir(acq)
% Switch the paths pointing to the pixcov and bin files to the local temp
% dir.

tempDir = acq.acqName;

pixCovName = acq