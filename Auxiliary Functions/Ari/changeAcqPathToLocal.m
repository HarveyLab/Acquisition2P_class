function changeAcqPathToLocal(path)
%changePathToLocal.m Looks in path for acq objects necessary for roi
%selection, and changes path in object to allow for proper local
%processing.
%
%INPUTS
%path - path to local folder containing acq objects. If empty, opens
%   uigetdir
%
%ASM 12/14

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

%find acq objects
acqFile = fileList{~cellfun(@isempty, regexp(fileList, '[A-Z]{2}\d{3}_\d{6}_acq.mat'))};
[~, acqName] = fileparts(acqFile);
serverAcqPath = fullfile(path,acqFile);

%load acqObject
loadVar = load(serverAcqPath);
objName = fields(loadVar);
acqObj = loadVar.(objName{1});

%replace indexedMovie location
for sliceNum = 1:length(acqObj.indexedMovie.slice)
    for channelNum = 1:length(acqObj.indexedMovie.slice.channel)
        oldIndexedMoviePath = acqObj.indexedMovie.slice(sliceNum).channel(channelNum).fileName;
        [~,movieName,movieExt] = fileparts(oldIndexedMoviePath);
        newIndexedMoviePath = fullfile(path,[movieName,movieExt]);
        acqObj.indexedMovie.slice(sliceNum).channel(channelNum).fileName = newIndexedMoviePath;
    end
end

%replace roiInfo 
for sliceNum = 1:length(acqObj.roiInfo.slice)
    oldRoiFileName = acqObj.roiInfo.slice(sliceNum).covFile.fileName;
    [~,roiName,roiExt] = fileparts(oldRoiFileName);
    newRoiFileName = fullfile(path,[roiName,roiExt]);
    acqObj.roiInfo.slice(sliceNum).covFile.fileName = newRoiFileName;
end

%save
localAcqPath = fullfile(path,sprintf('%s_local.mat', acqName));
eval(sprintf('%s = acqObj;',objName{1}));
save(localAcqPath,objName{1});

