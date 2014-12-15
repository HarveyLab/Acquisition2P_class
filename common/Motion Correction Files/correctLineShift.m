function varargout = correctLineShift(mov, manualShift)
% [movCorrected, shifts] = correctLineShift(mov) corrects the offset
% between odd and even image lines caused by bidirectional laser scanning.
% Apply this correction before any other processing.

if ~exist('manualShift', 'var') || isempty(manualShift)
    manualShift = NaN;
end

% Get size:
[origH, origW, origZ] = size(mov);

if ~isnan(manualShift)
    % Manual shift only:
    if numel(manualShift)==1
        origShiftedInd = circshift((1:origW)', manualShift);
        for f = 1:origZ
            mov(2:2:end, :, f) = mov(2:2:end, origShiftedInd, f);
        end
    else
        for f = 1:origZ
            origShiftedInd = circshift((1:origW)', manualShift(f));
            mov(2:2:end, :, f) = mov(2:2:end, origShiftedInd, f);
        end
    end
    varargout{1} = mov;
    return
end

% Crop image by 30%:
hCrop = ceil(origH*0.15);
wCrop = ceil(origW*0.15);

% Find optimal shift by calculating difference between unshifted odd lines
% and shifted even lines for different shift values:
maxAbsShift = 3;
sh          = -maxAbsShift:1:maxAbsShift;
nSh         = numel(sh);
movOrig     = reshape(mov(hCrop:2:end+1-hCrop, wCrop:end+1-wCrop, :), [], origZ);
diffs       = nan(origZ, nSh);
shiftedInd  = nan(origW, nSh);
for s = 1:nSh
    shiftedInd(:, s)    = circshift((1:origW)', sh(s));    
    movShifted          = reshape(mov(hCrop+1:2:end+1-hCrop,  shiftedInd(wCrop:end+1-wCrop, s), :), [], origZ);
    diffs(:, s)         = mean(abs(movOrig-movShifted), 1);
end
[bestCorr, iBestSh] = min(diffs, [], 2);

% Find "consensus" shift values by mode filtering:
% (Mode filtering is implemented by using im2col to slide a window across
% iBestSh, and then using histc to count which shift-index is most common
% in each window.
windowSize = 100; % Hard-coded window size, should be adjusted for different frame rates.
t = im2col(iBestSh, [windowSize, 1], 'sliding');
t = histc(t,1:nSh);
[~, iBestSh] = max(t, [], 1);
iBestSh(end+1:end+windowSize-1) = iBestSh(end); % Fill up to full length since the sliding window in im2col doesn't pad.
iBestSh = iBestSh(:);

%% Correct movie:
% Create shiftedInd for non-cropped movie:
[origSh, ~, iOSh]  = unique(sh(iBestSh));
origShiftedInd = nan(origW, numel(origSh));
for s = 1:numel(origSh)
    origShiftedInd(:, s) = circshift((1:origW)', origSh(s));
end

for f = 1:origZ
    mov(2:2:end, :, f) = mov(2:2:end, origShiftedInd(:, iOSh(f)), f);
end

%% Output arguments
varargout{1} = mov;
if nargout > 1
    varargout{2} = sh(iBestSh);
end
if nargout > 2
    varargout{3} =  bestCorr;
end