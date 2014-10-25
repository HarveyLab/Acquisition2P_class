function indexMovie(obj,nSlice,nChannel,writeDir)
%Function for creating a single large binary file containing an entire
%movie for a given slice/channel, allowing rapid, indexed access to pixel
%values. Needed to view ROI traces online within selectROIs GUI
%
%writeDir is the location to write the binary file to, defaults to defaultDir

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

%% 
thisFileName = sprintf('_slice%02.0f_chan%02.0f_mov.bin',nSlice,nChannel);
movFileName = fullfile(writeDir,[obj.acqName, thisFileName]);
obj.indexedMovie.slice(nSlice).channel(nChannel).fileName = movFileName;
fprintf('Saving file %s\n',movFileName),
hMovFile = fopen(movFileName,'a');
for nMovie = 1:length(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName)
    fprintf('Saving movie %03.0f of %03.0f\n',nMovie,length(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName)),
    mov = readCor(obj,nMovie,[],nSlice,nChannel);
    nFrames = size(mov,3);
    mov = reshape(mov,[],nFrames);
    fwrite(hMovFile,mov,'uint16');
end
fclose(hMovFile);
