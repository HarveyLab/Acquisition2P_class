function acq2tempDir(acq, dirTemp)
% Switch the paths pointing to the pixcov and bin files to the local temp
% dir.

acq.defaultDir = dirTemp;

if isfield(acq.roiInfo.slice, 'covFile')
    [~, filename, ext] = fileparts(acq.roiInfo.slice.covFile.fileName);
    acq.roiInfo.slice.covFile.fileName = fullfile(dirTemp, [filename, ext]);
    disp('Changed covFile path.')
end

if isfield(acq.roiInfo.slice, 'NMF')
    [~, filename, ext] = fileparts(acq.roiInfo.slice.NMF.filename);
    acq.roiInfo.slice.NMF.filename = fullfile(dirTemp, [filename, ext]);
    [~, filename, ext] = fileparts(acq.roiInfo.slice.NMF.traceFn);
    acq.roiInfo.slice.NMF.traceFn = fullfile(dirTemp, [filename, ext]);
    disp('Changed NMF path.')
end

if isfield(acq.roiInfo.slice, 'deconv')
    [~, filename, ext] = fileparts(acq.roiInfo.slice.deconv.filename);
    acq.roiInfo.slice.deconv.filename = fullfile(dirTemp, [filename, ext]);
    disp('Changed deconv path.')
end

if isfield(acq.indexedMovie.slice.channel(1), 'memMap')
    [~, filename, ext] = fileparts(acq.indexedMovie.slice.channel(1).memMap);
    acq.indexedMovie.slice.channel(1).memMap = fullfile(dirTemp, [filename, ext]);
    disp('Changed memmap path.')
end

if isfield(acq.indexedMovie.slice.channel(1), 'fileName')
    [~, binMovName, ext] = fileparts(acq.indexedMovie.slice.channel(1).fileName);
    acq.indexedMovie.slice.channel(1).fileName = fullfile(dirTemp, [binMovName, ext]);
    disp('Changed binary movie path.')
end


