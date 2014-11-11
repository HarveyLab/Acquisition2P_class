function [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, siStruct)

% Get rid of additional SI struct layer:
if isfield(siStruct, 'SI4')
    siStruct = siStruct.SI4;
end

% Nomenclature: frames and slices refer to the concepts used in
% ScanImage.
fZ              = siStruct.fastZEnable;
nChannels       = numel(siStruct.channelsSave);
nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).

% Copy data into structure:
for sl = 1:nSlices-(fZ*siStruct.fastZDiscardFlybackFrames) % Slices, removing flyback.
    for ch = 1:nChannels % Channels
        frameInd = ch + (sl-1)*nChannels;
        movStruct.slice(sl).channel(ch).mov = mov(:, :, frameInd:(nSlices*nChannels):end);
    end
end

nSlices = nSlices-(fZ*siStruct.fastZDiscardFlybackFrames);