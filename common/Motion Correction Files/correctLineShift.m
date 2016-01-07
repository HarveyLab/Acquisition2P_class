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

% Take temporal average:
% (Originally, this function measured the shifts for every frame
% individually and then found a consensus, but this didn't work well for
% very dim movies. The function was thus changed to find the shift for the
% temporal average of the entire movie, which is OK because the shift
% typically changes very slowly.)
movMean = mean(mov, 3);
movMean = movMean - mean(movMean(:));

% Crop image by 30%:
% We need to make sure that the cropping removes an even number of lines so
% that odd/even lines in the full image are still odd/even in the
% cropped image! So hCrop and wCrop, which are the index of the first
% included pixel, should both be odd.
makeOdd = @(a) a+(mod(a, 2)==0);
hCrop = makeOdd(ceil(origH*0.15));
wCrop = makeOdd(ceil(origW*0.15));

% Find optimal shift by calculating difference between unshifted odd lines
% and shifted even lines for different shift values:
maxAbsShift = 3;
sh          = -maxAbsShift:1:maxAbsShift;
nSh         = numel(sh);
linesOdd    = movMean(hCrop:2:end+1-hCrop, wCrop:end+1-wCrop, :);
corrs       = nan(1, nSh);
shiftedInd  = nan(origW, nSh);
for s = 1:nSh
    shiftedInd(:, s)    = circshift((1:origW)', sh(s));    
    linesEvenShifted    = movMean(hCrop+1:2:end+1-hCrop,  shiftedInd(wCrop:end+1-wCrop, s), :);
    corrs(:, s)         = corr(linesOdd(:), linesEvenShifted(:));
end
[bestCorr, iBestSh] = max(corrs, [], 2);

%% Correct movie:
% Create shiftedInd for non-cropped movie:
origShiftedInd = circshift((1:origW)', sh(iBestSh));

for f = 1:origZ
    mov(2:2:end, :, f) = mov(2:2:end, origShiftedInd, f);
end

%% Output arguments
varargout{1} = mov;
if nargout > 1
    varargout{2} = sh(iBestSh);
end
if nargout > 2
    varargout{3} =  bestCorr;
end