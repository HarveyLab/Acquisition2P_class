function [traces, rawF, roi, traceNeuropil] = ...
    extractROIsBinWithEdgeSubtraction(obj,roiGroups,sliceNum,channelNum)
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

%% Memory mapping:
%Memory Map Movie
movSizes = obj.correctedMovies.slice(1).channel(1).size;
h = movSizes(1, 1);
w = movSizes(1, 2);
nFramesTotal = sum(movSizes(:, 3));

movMap = memmapfile(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
    'Format', {'int16', [nFramesTotal, h*w], 'mov'});
mov = movMap.Data.mov;

%% Get mean edge signal:
% Find edge regions:
colBrightness = nanmedian(obj.meanRef);
colBrightnessSort = sort(colBrightness);
[~, ind] = max(diff(colBrightnessSort));
threshold = colBrightnessSort(ind);
edgeCols = find(mean(obj.meanRef>threshold)<0.01);

% Extract edge signal:
edgeSignal = zeros(h, nFramesTotal);
nCols = numel(edgeCols);
fprintf('Extracting edge signal...');
for ii = 1:nCols
    fprintf('.');
    colInd = sub2ind([h, w], 1:h, repmat(edgeCols(ii), 1, h));
    colIndMov = obj.mat2binInd(colInd);
    edgeSignal = edgeSignal + double(mov(:, colIndMov)'/nCols);
end
fprintf('\n');

%% ROI Extraction
%Find relevant ROIs
isRoiSelected = ismember([obj.roiInfo.slice(sliceNum).roi.group], roiGroups);
roi = obj.roiInfo.slice(sliceNum).roi(isRoiSelected);

% Loop over each ROI to be extracted:
nRoi = numel(roi);
traces = nan(nRoi, nFramesTotal);
rawF = nan(nRoi, nFramesTotal);
traceNeuropil = nan(nRoi, nFramesTotal);

for r = 1:nRoi
    fprintf('Extracting ROI %03.0f of %03.0f\n', r, nRoi);
    
    indCell = obj.mat2binInd(roi(r).indBody);
    
    % Find which part of the edge trace we have to subtract: (This
    % automatically takes into account how many pixels the ROI has on each
    % row.);
    [rCell, ~] = ind2sub([h, w], indCell);
    thisEdge = mean(edgeSignal(rCell, :), 1);
    
    traceCell = mean(mov(:, indCell), 2)';
    rawF(r,:) = traceCell-thisEdge;    
    
    if isfield(roi(r),'indNeuropil') && ~isempty(roi(r).indNeuropil)
        subCoef = roi(r).subCoef;
        indNeuropil = obj.mat2binInd(roi(r).indNeuropil);
        
        % Find which part of the edge trace we have to subtract: (This
        % automatically takes into account how many pixels the ROI has on each
        % row.);
        [rCell, ~] = ind2sub([h, w], indNeuropil);
        thisEdge = mean(edgeSignal(rCell, :), 1);
        
        traceNeuropil(r,:) = mean(mov(:, indNeuropil), 2)' - thisEdge;
        traces(r,:) = rawF(r,:) - traceNeuropil(r,:)*subCoef;
    else
        traces(r,:) = rawF(r,:);
    end
end

clear mov