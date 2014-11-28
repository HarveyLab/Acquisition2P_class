function trEdge = getEdgeTrace(acq)
% trEdge = getEdgeTrace(acq) returns the pixel values at the edge of the
% frame for each line independently.

h = acq.derivedData(1).size(1);
w = acq.derivedData(1).size(2);
nFramesTotal = cat(1, acq.derivedData.size);
nFramesTotal = sum(nFramesTotal(:, 3));

% Find edges:
colBrightness = nanmedian(acq.meanRef);
colBrightnessSort = sort(colBrightness);
[~, ind] = max(diff(colBrightnessSort));
threshold = colBrightnessSort(ind);
edge = repmat(mean(acq.meanRef>threshold)<0.01, size(acq.meanRef, 1), 1);
nCols = sum(edge(1, :));
[edgeRow, edgeCol] = find(edge);

movInd = sub2ind(acq.derivedData(1).size(1:2), edgeRow, edgeCol);

% Get the pixels from the binary file:
movMap = memmapfile(acq.indexedMovie.slice(1).channel(1).fileName,...
    'Format', {'int16', [nFramesTotal, h*w], 'mov'});

mov = movMap.Data.mov(:, acq.mat2binInd(movInd(:)));
mov = reshape(mov, nFramesTotal, nCols, []);
mov = mean(mov, 2); % Average across columns
mov = squeeze(mov)';