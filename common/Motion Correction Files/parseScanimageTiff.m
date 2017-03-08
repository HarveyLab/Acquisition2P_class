function [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, siStruct)

% Check for scanimage version before extracting metainformation
if isfield(siStruct, 'SI4')
    siStruct = siStruct.SI4;
    % Nomenclature: frames and slices refer to the concepts used in
    % ScanImage.
    fZ              = siStruct.fastZEnable;
    nChannels       = numel(siStruct.channelsSave);
    nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).
elseif isfield(siStruct, 'SI') % scanimage 2015 file
    fZ              = siStruct.SI.hFastZ.enable;
    nChannels       = length(siStruct.SI.hChannels.channelSave);
    if fZ
        nSlices = siStruct.SI.hFastZ.numFramesPerVolume;
        siStruct.fastZDiscardFlybackFrames = siStruct.SI.hFastZ.discardFlybackFrames;
    else
        nSlices = 1;
    end
elseif isfield(siStruct,'SI5')
     siStruct = siStruct.SI5;
    % Nomenclature: frames and slices refer to the concepts used in
    % ScanImage.
    fZ              = siStruct.fastZEnable;
    nChannels       = numel(siStruct.channelsSave);
    nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).
elseif isfield(siStruct, 'software') && siStruct.software.version < 4 %ie it's a scanimage 3 file
    fZ = 0;
    nSlices = 1;
    nChannels = siStruct.acq.numberOfChannelsSave;
else
    error('Movie is from an unidentified scanimage version, or metadata is improperly formatted'),
end


% Copy data into structure: - modeifed by SK 16/09/01

nSet = nSlices * nChannels; % how many sets of frames exist? (including flyback frames)
nCumFrame = (movNum-1) * size(mov,3); % cumulative sum of frames up to this movie
firstInd = mod(nCumFrame+(1:nSet)-1,nSet) + 1; % Which frame set do the first nSet frames of the movie correspond to?

if nSlices>1
    for sl = 1:nSlices-(fZ*siStruct.fastZDiscardFlybackFrames) % Slices, removing flyback.
        for ch = 1:nChannels % Channels
            frameInd = find(firstInd==(ch + (sl-1)*nChannels),1,'first');
            movStruct.slice(sl).channel(ch).mov = mov(:, :, frameInd:(nSlices*nChannels):end);
        end
    end
    nSlices = nSlices-(fZ*siStruct.fastZDiscardFlybackFrames);
else
    for sl = 1;
        for ch = 1:nChannels % Channels
            frameInd = find(firstInd==(ch + (sl-1)*nChannels),1,'first');
            movStruct.slice(sl).channel(ch).mov = mov(:, :, frameInd:(nSlices*nChannels):end);
        end
    end
end
