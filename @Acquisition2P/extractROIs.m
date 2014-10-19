function [traces,rawF,roiList] = extractROIs(obj,roiGroups,movNums,sliceNum,channelNum)

% Function for extracting ROIs from movies. Takes in grouping numbers and
% movies, defaults to all groups and all movies. Operates on tif files to
% save time on loading. Automatically subtracts neuropil when present, but
% this option can be disabled

%% Input Handling
if ~exist('sliceNum','var') || isempty(sliceNum)
    sliceNum = 1;
end
if ~exist('channelNum','var') || isempty(channelNum)
    channelNum = 1;
end
if ~exist('movNums','var') || isempty(movNums)
    movNums = 1:length(obj.correctedMovies.slice(sliceNum).channel(channelNum).fileName);
end
if ~exist('roiGroups','var') || isempty(roiGroups)
    roiGroups = 1:9;
end

%% ROI Extraction

%Find relevant ROIs
roiGroup = obj.roiInfo.slice(sliceNum).grouping;
roiList = find(ismember(roiGroup,roiGroups));

%Memory Map Movie
imSize = size(obj.roiInfo.slice(sliceNum).roiLabels);
movMap = memmapfile(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName,'Format','uint16');
mov = reshape(movMap.data,imSize(1)*imSize(2),[]);

%Construct matrix of ROI values
traces = [];
rawF = [];
for nROI = 1:length(roiList)
    fprintf('Extracting ROI %03.0f of %03.0f\n',nROI,length(roiList)),
    if ~isempty(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indNeuropil)
        subCoef = obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).subCoef;
        traces(nROI,:) = mean(mov(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indBody,:)) - ...
        mean(mov(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indNeuropil,:))*subCoef;
        rawF(nROI,:) = mean(mov(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indBody,:));
    else
        traces(nROI,:) = mean(mov(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indBody,:));
        rawF(nROI,:) = traces(nROI,:);
    end
end

clear mov