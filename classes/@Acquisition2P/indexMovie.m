function indexMovie(obj, nSlice, nChannel, writeDir)
%Function for creating a single large binary file containing an entire
%movie for a given slice/channel, allowing rapid, indexed access to pixel
%values. Needed to view ROI traces online within selectROIs GUI.
%
%indexMovie(obj,nSlice,nChannel,writeDir)
%
%writeDir is the location to write the binary file to, defaults to defaultDir
%
%Note the order of data in the binary file: first come all frames for pixel
%1, then come all frames for the adjacent pixel in the next COLUMN, and
%after all the pixels in that column come the pixels in the next row. This
%is the opposite row/col order than in Matlab, but is required due to the
%way TIFF files are saved. To access the trace for a particular pixel, use
%this kind of indexing:
% movRows = height_of_your_movie;
% movCols = width_of_you_movie;
% nFrames = number of frames in the acquisition;
% nPix = movRows*movCols;
% map = memmapfile(binFilePath, 'Format', {'int16', [nFrames, nPix], 'mov'});
% matlabPixelIndex = 12345; % Whatever pixel(s) you want to query.
% [pixRow, pixCol] = ind2sub([movRows, movCols], matlabPixelIndex);
% binFilePixelIndex = sub2ind([movCols, movRows], pixCol, pixRow); % Note how row/col are swapped with respect to Matlab convention.
% traceForPix = map.Data.mov(:, binFilePixelIndex);

%% Input handling
if ~exist('writeDir','var') || isempty(writeDir)
    writeDir = obj.defaultDir;
end

if ~exist('nSlice','var') || isempty(nSlice)
    nSlice = 1;
end

if ~exist('nChannel','var') || isempty(nChannel)
    nChannel = 1;
end

%% Create new binary movie file:
thisFileName = sprintf('_slice%02.0f_chan%02.0f_mov.bin',nSlice,nChannel);
movFileName = fullfile(writeDir,[obj.acqName, thisFileName]);

% Check if file exists and create unique name if it does:
if exist(movFileName, 'file')
    warning('File %s\nalready exists. Creating new file with different name.', thisFileName);
    thisFileName = [thisFileName(1:end-4), '_', datestr(now, 'YYMMDD_hh-mm-ss'), '.bin'];
    movFileName = fullfile(writeDir,[obj.acqName, thisFileName]);
end

fprintf('Saving file %s\n',movFileName);
fid = fopen(movFileName, 'A');

%% Write bin file in frame-major order:
fileList = sort(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName);
nFiles = numel(fileList);

% Create Tiff object:
t = Tiff.empty;
for f = fileList(:)' % Deal with both column and row cell arrays.
    t(end+1) = Tiff(f{:});
end

% Get file info:
movSizes = obj.correctedMovies.slice(nSlice).channel(nChannel).size;
h = movSizes(1, 1);
w = movSizes(1, 2);
nFrames = movSizes(:, 3);
nFramesTotal = sum(nFrames);
nStrips = t(1).numberOfStrips;
stripHeight = h/nStrips;
thisStrip = zeros(stripHeight, w, nFramesTotal, 'int16');

tTotal = tic;
for iStrip = 1:nStrips
    
    % Read current strip from all files:
    for iFile = 1:nFiles
        tFile = tic;
        
        for iFrame = 1:nFrames(iFile)
            iFrameGlobal = sum(nFrames(1:iFile-1)) + iFrame;
            t(iFile).setDirectory(iFrame);
            thisStrip(:, :, iFrameGlobal) = readEncodedStrip(t(iFile), iStrip);
        end
        
        if iFile==1 || ~mod(iFile, 10)
            fprintf('Reading strip %d of file %d: %1.3f\n', iStrip, iFile, toc(tFile));
        end
    end
    
    % Change shape of strip such that continuous rows of pixels will be
    % written, rather than blocks of rows of length stripHeight. This means
    % that the pixel order in the binary file will be column-major (the
    % opposite of Matlab). This is caused by the fact that TIFF strips are
    % horizontal, not vertical.
    thisStripBinShape = permute(thisStrip, [2, 1, 3]);
    thisStripBinShape = reshape(thisStripBinShape, [], nFramesTotal);
    thisStripBinShape = thisStripBinShape';
    
    % Write current strip to bin file:    
    tWrite = tic;
    fwrite(fid, thisStripBinShape, 'int16');
    fprintf('Writing strip %d: %1.3f\n', iStrip, toc(tWrite));
end
fprintf('Done saving binary movie. Total time per TIFF file: %1.3f\n', toc(tTotal)/iFile);

fclose(fid);

% Add info to acq2p object last in case an error happens in the function:
obj.indexedMovie.slice(nSlice).channel(nChannel).fileName = movFileName;

function [h, w, nFrames] = getTiffSize(tiffObj)
tiffObj.setDirectory(1);
[h, w] = size(tiffObj.read);  

while ~tiffObj.lastDirectory
    tiffObj.nextDirectory;
end
nFrames = tiffObj.currentDirectory;
tiffObj.setDirectory(1);