function acq = mjlmInitialization(acqId, savePath, acqName)
% acq = mjlmInitialization(acqId, savePath) - acqId (formerly fileId) is
% some fragment of the file name of the current acquisition that is unique
% to the current acquisition.

if nargin < 3
    acqName = acqId;
end

% Escape acqId because it will be used as a filename:
acqName = regexprep(acqName, '[\\/:*?"<>|]', '_');
acqName = regexprep(acqName, '_+', '_');

% Trim trailing underscores:
acqName = regexprep(acqName, '_$', '');

acq = Acquisition2P(acqName, @(acq) init(acq, acqId));

if exist('savePath', 'var')
    save(fullfile(savePath, acq.acqName), 'acq');
end

fprintf('Successfully created acquisition %s with %d movies.\n', acq.acqName, numel(acq.Movies));

function init(acq, acqId)
% Add remote files:
acq.Movies = improc.findFiles(acqId, '\\User1-PC\D\data\Matthias', 0);

% Set default dir to local "processed" dir:
[~, host] = system('hostname');
host = strtrim(host);
switch host
%     case 'Matthias-X230'
%         acq.defaultDir = improc.dir.getDir(acqId, 1, 1);
    otherwise
%         acq.defaultDir = improc.dir.getDir(acqId, 0, 1);
        localScopeRigFolder = fullfile('\\User1-PC\D\data\Matthias\processed', acqId);
        mkdir(localScopeRigFolder);
        fprintf('Created new folder: %s\n', localScopeRigFolder);
        acq.defaultDir = localScopeRigFolder;
end

% Motion correction parameters:
acq.motionCorrectionFunction = @withinFile_withinFrame_lucasKanade;
acq.motionRefMovNum = floor(length(acq.Movies)/2);
acq.motionRefChannel = 1;
acq.binFactor = 1;