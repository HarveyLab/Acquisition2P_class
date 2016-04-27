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

acq = Acquisition2P(acqName, @(acq) init(acq, acqId, savePath));

if exist('savePath', 'var')
    save(fullfile(savePath, acq.acqName), 'acq');
end

fprintf('Successfully created acquisition %s with %d movies.\n', acq.acqName, numel(acq.Movies));

function init(acq, acqId, savePath)
% Add remote files:

% Check which rig this acq will be processed on, by looking at the path
% where the job file will be saved:
if ~isempty(strfind(savePath, 'jobsToDoScopeRig'))
     acq.Movies = improc.findFiles(acqId, '\\User1-PC\D\data\Matthias', 0);
     host = 'scopeRig';
elseif ~isempty(strfind(savePath, 'jobsToDoKristenPc'))
    acq.Movies = improc.findFiles(acqId, '\\user-pc\C\data\Matthias\imaging\raw', 0);
    host = 'kristenPc';
elseif ~isempty(strfind(savePath, 'jobsToDoTarynPc'))
    % On taryn's pc, pull raw files from server (but then save in local
    % default dir):
    acq.Movies = improc.findFiles(acqId, '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw', 0);
    host = 'tarynPc';
elseif ~isempty(strfind(savePath, 'jobsToDoOrchestra'))
    % For orchestra, get the file paths from the server but then change
    % them to the orchestra paths:
    movieList = improc.findFiles(acqId, '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw', 0);
    for i = 1:numel(movieList)
        movieList{i} = strrep(movieList{i}, ...
            '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw', ...
            '/n/data2/hms/neurobio/harvey/matthias/imaging/raw');
        movieList{i} = strrep(movieList{i}, '\', '/');
    end
    acq.Movies = movieList;
    host = 'orchestra';
end

% Abort if no movies were found:
if isempty(acq.Movies)
    error('No movies were found.')
end

% Set default dir to local "processed" dir:
switch host
    case 'Matthias-X230'
        acq.defaultDir = improc.dir.getDir(acqId, 1, 1);
    case 'scopeRig'
        localScopeRigFolder = fullfile('\\User1-PC\D\data\Matthias\processed', acqId);
    case 'kristenPc'
        localScopeRigFolder = fullfile('\\user-pc\C\data\Matthias\imaging\processed', acqId);
    case 'tarynPc'
        localScopeRigFolder = fullfile('\\taryn-pc\C\DATA\Matthias\imaging\processed', acqId);
    case 'orchestra'
        localScopeRigFolder = ['/n/data2/hms/neurobio/harvey/matthias/imaging/processed/', acqId, '/'];
        
end

% Create local "processed" dir:
% if ~exist(localScopeRigFolder, 'dir')
%     mkdir(localScopeRigFolder);
%     fprintf('Created new folder: %s\n', localScopeRigFolder);
% end
acq.defaultDir = localScopeRigFolder;

% Motion correction parameters:
acq.motionCorrectionFunction = @withinFile_withinFrame_lucasKanade;
acq.motionRefMovNum = max(floor(length(acq.Movies)/2), 1);
acq.motionRefChannel = 1;
acq.binFactor = 1;