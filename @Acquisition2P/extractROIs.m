function [traces,rawF,roiList] = extractROIs(obj,roiGroups,sliceNum,channelNum)
% Function for extracting ROIs from movies using grouping assigned by
% selectROIs. This function uses a memorymapped binary file of the entire
% movie, as output by indexMovie. See extractROIsTIFF to extract ROIs
% from tiff files instead
%
% [traces,rawF,roiList] = extractROIs(obj,roiGroups,sliceNum,channelNum)
%
% roiGroups is a scalar or vector of desired groupings to extract ROIs for, defaults to all grouping (1:9)
% traces - matrix of n_cells x n_frames fluorescence values, using neuropil correction for ROIs with a matched neuropil ROI
% rawF - matrix of same size as traces, but without using neuropil correction
% roiList - vector of ROI numbers corresponding to extracted ROIs


%% Input Handling
if ~exist('sliceNum','var') || isempty(sliceNum)
    sliceNum = 1;
end
if ~exist('channelNum','var') || isempty(channelNum)
    channelNum = 1;
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

%Loop over each ROI,
traces = [];
rawF = [];
for nROI = 1:length(roiList)
    fprintf('Extracting ROI %03.0f of %03.0f\n',nROI,length(roiList)),
    if isfield(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)),'indNeuropil') ...
        && ~isempty(obj.roiInfo.slice(sliceNum).roi(roiList(nROI)).indNeuropil)
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