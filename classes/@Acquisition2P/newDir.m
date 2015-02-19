function newDir(obj,destDir,doCor,doInd,doCov)
%Copies an acquisition and the associated motion corrected files from
%the original location to a new one, and creates a new acquisition
%object associated with the new location.
%
%newDir(obj,destDir,doCor,doInd,doCov)
%destDir is the directory to which files will be copied, and the new
%   default directory for the copied acquisition
%doCor\Ind\Cov are logicals specifying whether to copy corrected tiffs,
%   indexed movie files, and covariance files, respectively. newDir always
%   checks to see whether files are present before copying, so all 'do' variables can be set
%   to one without throwing an error
    
%% Input handling

if ~exist('doCor', 'var') || isempty(doCor)
    doCor = 1;
end

if ~exist('doInd', 'var') || isempty(doInd)
    doInd = 1;
end

if ~exist('doCov', 'var') || isempty(doCov)
    doCov = 1;
end

%% Copy files
if doCor == 1
nSlices = length(obj.correctedMovies.slice);
nChannels = length(obj.correctedMovies.slice(1).channel);
elseif doInd == 1
nSlices = length(obj.indexedMovie.slice);
nChannels = length(obj.indexedMovie.slice(1).channel);
else
nSlices = length(obj.roiInfo.slice);
nChannels = length(obj.roiInfo.slice(1).channel);
end

for nSlice = 1:nSlices
    fprintf('\n Copying Slice %02.0f of %02.0f\n',nSlice,nSlices)
    for nChannel = 1:nChannels
        fprintf('\n Copying Channel %02.0f of %02.0f\n',nChannel,nChannels)
        if doCor && ~isempty(obj.correctedMovies)
            for nFile = 1:length(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName)
                fprintf('Copying Movie %03.0f of %03.0f\n',nFile,length(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName))
                [movPath,movName,movExt] = fileparts(obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{nFile});
                movName = [movName movExt];
                newMovName = fullfile(destDir,movName);
                copyfile(fullfile(movPath,movName),newMovName);
                obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{nFile} = newMovName;
            end
        end
        if doInd && ~isempty(obj.indexedMovie)
            fprintf('\n Copying Indexed Movie'),
            [movPath,movName,movExt] = fileparts(obj.indexedMovie.slice(nSlice).channel(nChannel).fileName);
            movName = [movName movExt];
            newMovName = fullfile(destDir,movName);
            copyfile(fullfile(movPath,movName),newMovName);
            obj.indexedMovie.slice(nSlice).channel(nChannel).fileName = newMovName;
        end
        if doCov && ~isempty(obj.roiInfo) && isfield(obj.roiInfo.slice(nSlice),'covFile')
            fprintf('\n Copying Pixel Covariance File\n'),
            [covPath,covName,covExt] = fileparts(obj.roiInfo.slice(nSlice).covFile.fileName);
            covName = [covName covExt];
            newCovName = fullfile(destDir,covName);
            copyfile(fullfile(covPath,covName),newCovName);
            obj.roiInfo.slice(nSlice).covFile.fileName = newCovName;
        end
            
    end
end
    
obj.defaultDir = destDir;
eval([obj.acqName '= obj;']);
save(fullfile(destDir,obj.acqName),obj.acqName);