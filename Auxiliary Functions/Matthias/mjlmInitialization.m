function mjlmInitialization(acqId)
% acqId (formerly fileId) is some fragment of the file name of the current
% acquisition that is unique to the current acquisition.
acq = Acquisition2P(acqId, @init);

function init(acq)
% Add remote files:
acq.Movies = improc.findFiles(acqId, 0, 0);

% Set default dir to local "processed" dir:
acq.defaultDir = improc.dir.getDir(acqId, 1, 1);

% Motion correction parameters:
obj.motionCorrectionFunction = @withinFile_withinFrame_lucasKanade;
obj.motionRefMovNum = floor(length(movNames)/2);
obj.motionRefChannel = 1;
obj.binFactor = 1;