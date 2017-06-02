function deconvNmf(acq)
% Wrapper function for NMF-source deconvolution.

% Matthias-specific: Some acqs from MM102 and MM104 have fake SI metadata
% because the code hadn't been updated for SI2016. Detect that here and get
% real metadata:
if isfield(acq.metaDataSI, 'SI4') || isempty(acq.metaDataSI)
    fPath = acq.Movies{1};
    [~, acq.metaDataSI] = tiffRead(fPath, [], 1, 0);
end

% NMF code requires syncInfo. Create minimal version if none is present:
if isempty(acq.syncInfo) || ~isfield(acq.syncInfo, 'sliceFrames') || ~isfield(acq.syncInfo, 'validFrameCount')
    % Create minimal syncInfo:
    acq.syncInfo.sliceFrames = sum(acq.correctedMovies.slice(1).channel(1).size(:, 3));
	acq.syncInfo.validFrameCount = acq.syncInfo.sliceFrames;
end

% Do deconvolution:
[dF,deconv,denoised,Gs,Lams,A,b,f] = extractTraces_NMF(acq); %#ok<ASGLU>

saveFile = fullfile(acq.defaultDir, ...
    sprintf('%s_deconvResults_v2.mat', acq.acqName));

for i = 1:numel(acq.correctedMovies.slice)
    acq.roiInfo.slice(i).deconv.filename = saveFile;
end

save(saveFile, 'dF', 'deconv', 'denoised', 'Gs', 'Lams', ...
    'A','b','f', '-v7.3')