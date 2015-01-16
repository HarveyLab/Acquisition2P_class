function [traces, rawF, roiList, roiGroup, traceNeuropil] = ...
    extractROIsBinWithEdgeSubtraction(acq,roiGroups,sliceNum,channelNum)
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

%% Memory mapping:
%Memory Map Movie
movSizes = acq.correctedMovies.slice(1).channel(1).size;
h = movSizes(1, 1);
w = movSizes(1, 2);
nFramesTotal = sum(movSizes(:, 3));

movMap = memmapfile(acq.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
    'Format', {'int16', [nFramesTotal, h*w], 'mov'});
mov = movMap.Data.mov;

%% Get mean edge signal:
colBrightness = nanmedian(acq.meanRef);
colBrightnessSort = sort(colBrightness);
[~, ind] = max(diff(colBrightnessSort));
threshold = colBrightnessSort(ind);
edgeCols = find(mean(acq.meanRef>threshold)<0.01);

edgeSignal = zeros(h, nFramesTotal);
nCols = numel(edgeCols);

for ii = 1:nCols
    ii
    colInd = sub2ind([h, w], 1:h, repmat(edgeCols(ii), 1, h));
    colIndMov = acq.mat2binInd(colInd);
    edgeSignal = edgeSignal + double(mov(:, colIndMov)'/nCols);
end

%% Roi extraction:
%Find relevant ROIs
roiGroup = [acq.roiInfo.slice.roi.group];
roiList = find(ismember(roiGroup, roiGroups));
roiGroup = roiGroup(roiList);
nRois = numel(roiList);

%Loop over each ROI,
traces = nan(nRois, nFramesTotal);
rawF = nan(nRois, nFramesTotal);
traceNeuropil = nan(nRois, nFramesTotal);

for nROI = 1:nRois
    fprintf('Extracting ROI %03.0f of %03.0f\n',nROI,length(roiList));
    
    thisRoi = acq.roiInfo.slice(sliceNum).roi(roiList(nROI));
    
    indCell = acq.mat2binInd(thisRoi.indBody);
    
    % Find which part of the edge trace we have to subtract: (This
    % automatically takes into account how many pixels the ROI has on each
    % row.);
    [rCell, ~] = ind2sub([h, w], indCell);
    thisEdge = mean(edgeSignal(rCell, :), 1);
    
    traceCell = mean(mov(:, indCell), 2)';
    rawF(nROI,:) = traceCell-thisEdge;    
    
    if isfield(thisRoi,'indNeuropil') && ~isempty(thisRoi.indNeuropil)
        subCoef = thisRoi.subCoef;
        indNeuropil = acq.mat2binInd(thisRoi.indNeuropil);
        
        % Find which part of the edge trace we have to subtract: (This
        % automatically takes into account how many pixels the ROI has on each
        % row.);
        [rCell, ~] = ind2sub([h, w], indNeuropil);
        thisEdge = mean(edgeSignal(rCell, :), 1);
        
        
        traceNeuropil(nROI,:) = mean(mov(:, indNeuropil), 2)' - thisEdge;
        
        traces(nROI,:) = traceCell - traceNeuropil(nROI,:)*subCoef;
    else
        traces(nROI,:) = rawF(nROI,:);
    end
end

clear mov