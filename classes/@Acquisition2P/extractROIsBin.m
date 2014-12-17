function [traces, rawF, roi, traceNeuropil] = ...
    extractROIsBin(obj,roiGroups,sliceNum,channelNum)
% Function for extracting ROIs from movies using grouping assigned by
% selectROIs. This function uses a memorymapped binary file of the entire
% movie, as output by indexMovie. See extractROIsTIFF to extract ROIs
% from tiff files instead
%
% [traces, rawF, roiList] = extractROIs(obj,roiGroups,sliceNum,channelNum)
%
% roiGroups is a scalar or vector of desired groupings to extract ROIs for, defaults to all grouping (1:9)
% traces - matrix of n_cells x n_frames fluorescence values, using neuropil correction for ROIs with a matched neuropil ROI
% rawF - matrix of same size as traces, but without using neuropil correction
% roiList - vector of ROI numbers corresponding to extracted ROIs
% roiGroup - vector of ROI groupings for each returned trace.


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

% Update roi information to new structure:
if isfield(obj.roiInfo.slice(sliceNum), 'roiList')
    removeRoiList(obj);
end

%% ROI Extraction

%Find relevant ROIs
isRoiSelected = ismember([obj.roiInfo.slice(sliceNum).roi.group], roiGroups);
roi = obj.roiInfo.slice(sliceNum).roi(isRoiSelected);

%Memory Map Movie
movSizes = obj.correctedMovies.slice(sliceNum).channel(channelNum).size;
h = movSizes(1, 1);
w = movSizes(1, 2);
nFramesTotal = sum(movSizes(:, 3));

movMap = memmapfile(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
    'Format', {'int16', [nFramesTotal, h*w], 'mov'});
mov = movMap.Data.mov;

% Loop over each ROI to be extracted:
nRoi = numel(roi);
traces = nan(nRoi, nFramesTotal);
rawF = nan(nRoi, nFramesTotal);
traceNeuropil = nan(nRoi, nFramesTotal);

for r = 1:nRoi
    fprintf('Extracting ROI %03.0f of %03.0f\n', r, nRoi);
    
    indCell = obj.mat2binInd(roi(r).indBody);
    traceCell = mean(mov(:, indCell), 2)';
    rawF(r,:) = traceCell;
    
    if isfield(roi(r),'indNeuropil') && ~isempty(roi(r).indNeuropil)
        subCoef = roi(r).subCoef;
        indNeuropil = obj.mat2binInd(roi(r).indNeuropil);
        traceNeuropil(r,:) = mean(mov(:, indNeuropil), 2)';
        traces(r,:) = traceCell - traceNeuropil(r,:)*subCoef;
    else
        traces(r,:) = rawF(r,:);
    end
end

clear mov