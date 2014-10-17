function indexMovie(obj,writeDir)

if ~exist('writeDir','var')
    writeDir = obj.defaultDir;
end

nSlices = length(obj.correctedMovies);
nChannels = length(obj.correctedMovies.slice(1));

for nSlice = 1:nSlices
    for nChannel = 1:nChannels
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
    end
end
            