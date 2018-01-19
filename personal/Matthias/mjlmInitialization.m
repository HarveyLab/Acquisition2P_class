function acq = mjlmInitialization(acqId, rawFileLocation, acqName)
% acq = mjlmInitialization(acqId, rawFileLocation, acqName)
%
% acqId (formerly fileId) is some fragment of the file name of the current
% acquisition that is unique to the current acquisition.
%
% rawFileLocation is where the tiff files are located. This can be one of
% the pre-defined shortcuts, or a path to a folder.
%
% acqName is optional, if the name of the acquisition object should not be
% the same as the acqId.

if nargin < 3
    acqName = acqId;
end

% Escape acqId because it will be used as a filename:
acqName = regexprep(acqName, '[\\/:*?"<>|]', '_');
acqName = regexprep(acqName, '_+', '_');

% Trim trailing underscores:
acqName = regexprep(acqName, '_$', '');

acq = Acquisition2P(acqName, @(acq) init(acq, acqId, rawFileLocation));

if exist('rawFileLocation', 'var')
    save(fullfile(rawFileLocation, acq.acqName), 'acq');
end

fprintf('Successfully created acquisition %s with %d movies.\n', acq.acqName, numel(acq.Movies));

function init(acq, acqId, rawFileLocation)
% Add remote files:

if contains(rawFileLocation, 'jobsToDoOrchestraAnna')
    mode = 'jobsToDoOrchestraAnna';
elseif contains(rawFileLocation, 'jobsToDoOrchestra')
    mode = 'jobsToDoOrchestra';
else
    mode = rawFileLocation;
end

% Check which rig this acq will be processed on, by looking at the path
% where the job file will be saved:
switch mode
    case 'jobsToDoScopeRig'
        acq.Movies = improc.findFiles(acqId, '\\User1-PC\D\data\Matthias', 0, [], 1);
        host = 'scopeRig';
        
    case 'jobsToDoKristenPc'
        acq.Movies = improc.findFiles(acqId, '\\user-pc\C\data\Matthias\imaging\raw', 0, [], 1);
        host = 'kristenPc';
        
    case 'jobsToDoTarynPc'
        % On taryn's pc, pull raw files from server (but then save in local
        % default dir):
        acq.Movies = improc.findFiles(acqId, '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw', 0, [], 1);
        host = 'tarynPc';
        
    case 'jobsToDoOrchestra'
        % For orchestra, get the file paths from the server but then change
        % them to the orchestra paths:
        movieList = improc.findFiles(acqId, '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw', 0, [], 1);
        for i = 1:numel(movieList)
            movieList{i} = strrep(movieList{i}, ...
                '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw', ...
                '/n/scratch2/mjm50');
            movieList{i} = strrep(movieList{i}, '\', '/');
        end
        acq.Movies = movieList;
        host = 'orchestra';
        
    case 'jobsToDoOrchestraAnna'
        % For orchestra, get the file paths from the server but then change
        % them to the orchestra paths:
        folderId = strsplit(acqId, '_');
        folderId = [folderId{1},  '_', folderId{2}]; % Anna's acqs can have a FOV field in the name, so cut that off.
        movieList = improc.findFiles(folderId, '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Tier1\Anna\Imaging\raw', 0, [], 1);
        
        % Sanitize list:
        isBad = false(size(movieList));
        for i = 1:numel(movieList)
            isBad(i) = isBad(i) | ~isempty(strfind(movieList{i}, 'overview'));
            isBad(i) = isBad(i) | isempty(strfind(movieList{i}, '.tif'));
        end
        
        movieList = movieList(~isBad);
        
        % Replace server path with Orchestra scratch:
        for i = 1:numel(movieList)
            movieList{i} = strrep(movieList{i}, ...
                '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Tier1\Anna\Imaging\raw', ...
                '/n/scratch2/mjm50/raw');
            movieList{i} = strrep(movieList{i}, '\', '/');
        end
        acq.Movies = movieList;
        host = 'orchestra';
        
    otherwise % Path to raw tiff folder is given:
        acq.Movies = improc.findFiles(acqId, rawFileLocation, 0, [], 1);
        host = 'manualPathWasGiven';
        
end

% Abort if no movies were found:
if isempty(acq.Movies)
    error('No movies were found.')
end

% Set default dir to local "processed" dir:
switch host
    case 'Matthias-X230'
        dirProcessed = improc.dir.getDir(acqId, 1, 1);
    case 'scopeRig'
        dirProcessed = fullfile('\\User1-PC\D\data\Matthias\processed', acqId);
    case 'kristenPc'
        dirProcessed = fullfile('\\user-pc\C\data\Matthias\imaging\processed', acqId);
    case 'tarynPc'
        dirProcessed = fullfile('\\taryn-pc\C\DATA\Matthias\imaging\processed', acqId);
    case 'orchestra'
%         dirProcessed = ['/n/data2/hms/neurobio/harvey/matthias/imaging/processed/', acqId, '/'];
        dirProcessed = ['/n/scratch2/mjm50/processed/', acqId, '/'];
    case 'manualPathWasGiven'
        dirProcessed = rawFileLocation; % Acq2p will create "corrected" folder.
        
end

% Create local "processed" dir:
% if ~exist(localScopeRigFolder, 'dir')
%     mkdir(localScopeRigFolder);
%     fprintf('Created new folder: %s\n', localScopeRigFolder);
% end
acq.defaultDir = dirProcessed;

% Motion correction parameters:
acq.motionCorrectionFunction = @lucasKanade_plus_nonrigid_memMap;
acq.motionRefMovNum = max(floor(length(acq.Movies)/2), 1);
acq.motionRefChannel = 1;
acq.binFactor = 1;