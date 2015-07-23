function [dF, traces, rawF, roi] = extractROIsTIFF(obj,roiGroups,movNums,sliceNum,channelNum)

% Function for extracting ROIs from movies using grouping assigned by
% selectROIs. This function motion corrected tiff files. See extractROI for a
% sometimes faster method using a memory mapped 'indexed' binary file instead.
%
% [dF, traces ,rawF ,roiList,roiMat,rawMat] = extractROIsTIFF(obj,roiGroups,movNums,sliceNum,channelNum)
%
% roiGroups is a scalar or vector of desired groupings to extract ROIs for, defaults to all grouping (1:9)
% movNums is a vector of movie numbers to use, defaults to all movies
% dF - dF calculation using (sub-baseSub)/baseRaw, w/ linear baseline extrapolation
% traces - matrix of n_cells x n_frames fluorescence values, using neuropil correction for ROIs with a matched neuropil ROI
% roi - structure of roi information for selected ROIs

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
isRoiSelected = ismember([obj.roiInfo.slice(sliceNum).roi.group], roiGroups);
roi = obj.roiInfo.slice(sliceNum).roi(isRoiSelected);
nROIs = numel(roi);

%Movie size information
movSizes = obj.correctedMovies.slice(sliceNum).channel(channelNum).size;
h = movSizes(1, 1);
w = movSizes(1, 2);
nFramesTotal = sum(movSizes(movNums, 3));
nFramesThisMov = cumsum(movSizes(movNums,3));

%Construct matrix of ROI values
roiMat = nan(h*w,nROIs);
rawMat = nan(h*w,nROIs);
for nROI = 1:nROIs
    mask = zeros(h,w);
    cellBodyInd = roi(nROI).indBody;
    mask(cellBodyInd) = 1/length(cellBodyInd);
    maskRaw = mask;
    if isfield(roi(nROI),'indNeuropil') && ~isempty(roi(nROI).indNeuropil)
        neuropilInd = roi(nROI).indNeuropil;
        subCoef = roi(nROI).subCoef;
        mask(neuropilInd) = -subCoef/length(neuropilInd);
    end
    roiMat(:,nROI) = reshape(mask,[],1);
    rawMat(:,nROI) = reshape(maskRaw,[],1);
end

%Loop over movie files, loading each individually and concatenating traces
traces = nan(nROIs, nFramesTotal);
rawF = nan(nROIs, nFramesTotal);
for nMovie = movNums
    fprintf('Loading movie %03.0f of %03.0f\n',find(nMovie==movNums),length(movNums)),
    mov = readCor(obj,nMovie,'double',sliceNum,channelNum);
    mov = reshape(mov,h*w,movSizes(nMovie,3));
    firstInd = nFramesThisMov(nMovie)-movSizes(nMovie,3)+1;
    lastInd = nFramesThisMov(nMovie);
    traces(:,firstInd:lastInd) = roiMat'*mov;
    rawF(:,firstInd:lastInd) = rawMat'*mov;
end

dF = dFcalc(traces,rawF,'linear');
