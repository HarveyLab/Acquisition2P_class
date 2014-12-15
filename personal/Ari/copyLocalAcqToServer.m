function copyLocalAcqToServer(path,serverPath)
%copyLocalAcqToServer.m Copies local acquisition back to server and fixes
%paths 
%
%INPUTS
%path - local path 
%
%ASM 12/14

if nargin < 2 || isempty(serverPath)
    serverPath = 'Z:\HarveyLab\Ari\2P Data\ResScan';
end

%check if path exists
if nargin < 1 || isempty(path)
    path = uigetdir('W:\ResScan');
end

%check if path is real
if ~exist(path,'dir')
    error('Path does not exist');
end

%get list of files in path
fileList = dir(path);
fileList = {fileList(:).name};
fileList = fileList(~ismember(fileList,{'.', '..'}));

%get mouse and date
pathParts = explode(path,filesep);
mouseName = pathParts{end-1};
fileDate = pathParts{end};

%add to server path
serverPath = fullfile(serverPath,mouseName,fileDate);

%find local acq objects
localAcqFile = fileList{~cellfun(@isempty, regexp(fileList, '[A-Z]{2}\d{3}_\d{6}_acq_local.mat'))};
[~, acqName] = fileparts(localAcqFile);
localAcqPath = fullfile(path,localAcqFile);

%remove local from acqName
acqName=regexp(acqName,'[A-Z]{2}\d{3}_\d{6}_acq','match');
acqName = acqName{1};

%load acqObject
loadVar = load(localAcqPath);
objName = fields(loadVar);
acqObj = loadVar.(objName{1});

%replace indexedMovie location
for sliceNum = 1:length(acqObj.indexedMovie.slice)
    for channelNum = 1:length(acqObj.indexedMovie.slice.channel)
        oldIndexedMoviePath = acqObj.indexedMovie.slice(sliceNum).channel(channelNum).fileName;
        [~,movieName,movieExt] = fileparts(oldIndexedMoviePath);
        newIndexedMoviePath = fullfile(serverPath,[movieName,movieExt]);
        acqObj.indexedMovie.slice(sliceNum).channel(channelNum).fileName = newIndexedMoviePath;
    end
end

%replace roiInfo 
for sliceNum = 1:length(acqObj.roiInfo.slice)
    oldRoiFileName = acqObj.roiInfo.slice(sliceNum).covFile.fileName;
    [~,roiName,roiExt] = fileparts(oldRoiFileName);
    newRoiFileName = fullfile(serverPath,[roiName,roiExt]);
    acqObj.roiInfo.slice(sliceNum).covFile.fileName = newRoiFileName;
end

%save
serverAcqPath = fullfile(serverPath,sprintf('%s.mat', acqName));
eval(sprintf('%s = acqObj;',objName{1}));
save(serverAcqPath,objName{1});