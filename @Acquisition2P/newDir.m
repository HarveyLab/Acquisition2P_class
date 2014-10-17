function newDir(obj,destDir)
    %Copies an acquisition and the associated motion corrected files from
    %the original location to a new one, and creates a new acquisition
    %object associated with the new location. Useful for transferring data
    %from server to local computer for faster reading/writing

nSlices = length(obj.correctedMovies.slice);
nChannels = length(obj.correctedMovies.slice(1).channel);

for nSlice = 1:nSlices
    fprintf('\n Copying Slice %02.0f of %02.0f\n',nSlice,nSlices)
    for nChannel = 1:nChannels
        fprintf('\n Copying Channel %02.0f of %02.0f\n',nChannel,nChannels)
        for nFile = 1:length(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName)
            fprintf('\n Copying Movie %03.0f of %03.0f',nFile,length(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName))
            [movPath,movName,movExt] = fileparts(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{nFile});
            movName = [movName movExt];
            newMovName = fullfile(destDir,movName);
            copyfile(fullfile(movPath,movName),newMovName);
            obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{nFile} = newMovName;
        end
        if ~isempty(obj.indexedMovie)
            fprintf('\n Copying Indexed Movie'),
            [movPath,movName,movExt] = fileparts(obj.indexedMovie.slice(nSlice).channel(nChannel).fileName);
            movName = [movName movExt];
            newMovName = fullfile(destDir,movName);
            copyfile(fullfile(movPath,movName),newMovName);
            obj.indexedMovie.slice(nSlice).channel(nChannel).fileName = newMovName;
        end
        if ~isempty(obj.roiInfo) && isfield(obj.roiInfo.slice(nSlice),'covFile')
            fprintf('\n Copying Pixel Covariance File\n'),
            [covPath,covName,covExt] = fileparts(obj.roiInfo.slice(nSlice).covFile);
            covName = [covName covExt];
            newCovName = fullfile(destDir,covName);
            copyfile(fullfile(covPath,covName),newCovName);
            obj.roiInfo.slice(nSlice).covFile = newCovName;
        end
            
    end
end
    

obj.defaultDir = destDir;
eval([obj.acqName '= obj;']);
save(fullfile(destDir,obj.acqName),obj.acqName);