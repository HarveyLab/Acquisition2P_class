function [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, siStruct)

% Check for scanimage version before extracting metainformation
if isfield(siStruct, 'SI4')
    siStruct = siStruct.SI4;
    % Nomenclature: frames and slices refer to the concepts used in
    % ScanImage.
    fZ              = siStruct.fastZEnable;
    nChannels       = numel(siStruct.channelsSave);
    nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).
elseif isfield(siStruct, 'software') && siTruct.software.version < 4 %ie it's a scanimage 3 file
    fZ = 0;
    nSlices = 1;
    nChannels = siStruct.acq.numberOfChannelsSave;
else
    error('Movie is from an unidentified scanimage version, or metadata is improperly formatted'),
end


% Copy data into structure:
for sl = 1:nSlices-(fZ*siStruct.fastZDiscardFlybackFrames) % Slices, removing flyback.
    for ch = 1:nChannels % Channels
        frameInd = ch + (sl-1)*nChannels;
        movStruct.slice(sl).channel(ch).mov = mov(:, :, frameInd:(nSlices*nChannels):end);
    end
end

nSlices = nSlices-(fZ*siStruct.fastZDiscardFlybackFrames);