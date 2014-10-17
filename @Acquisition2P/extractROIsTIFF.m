function [traces,roiList,roiMat] = extractROIsTIFF(obj,roiGroups,movNums,sliceNum,channelNum,doSubtraction)

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
if ~exist('doSubtraction','var') || isempty(doSubtraction)
    doSubtraction = 1;
end

%% ROI Extraction

%Find relevant ROIs
roiGroup = obj.roiInfo.slice(sliceNum).grouping;
roiList = find(ismember(roiGroup,roiGroups));

%Construct matrix of ROI values
roiMat = [];
for nROI = 1:length(roiList)
    mask = zeros(size(obj.roiInfo.slice(sliceNum).roiLabels));
    cellBodyInd = obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indBody;
    mask(cellBodyInd) = 1/length(cellBodyInd);
    if doSubtraction && ~isempty(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indNeuropil)
        neuropilInd = obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indNeuropil;
        subCoef = obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).subCoef;
        mask(neuropilInd) = -subCoef/length(neuropilInd);
    end
    roiMat(:,end+1) = reshape(mask,[],1);
end

traces = [];
for nMovie = movNums
    fprintf('Loading movie %03.0f of %03.0f\n',find(nMovie==movNums),length(movNums)),
    mov = readCor(obj,nMovie,'double');
    mov = reshape(mov,[],size(mov,3));
    traces = cat(2,traces,roiMat'*mov);
end

