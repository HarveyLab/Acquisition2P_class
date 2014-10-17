function success = acq2server(movPath,filesIn,acqName,fileDest)

%filesIn should be a cell array of tif files to use for populateMovieList
%Cell array can contain nested cell array of multiple files to populate a
%single acquisition object
%fileDest is optional and should be a string specifying the write directory
%acqName is cell array of acquisition names

defReadDir = 'C:\Data';
defWriteDir = 'Z:\HarveyLab\Selmaan';
if ~exist('fileDest','var')
    if ~isempty(strfind(movPath,defReadDir))
        fileDest = [defWriteDir movPath(length(defReadDir)+strfind(movPath,defReadDir):end)];
    else
        error('No destination provided and default cannot be constructed')
    end
end

nAcqs = length(filesIn);
if ~exist('acqName','var')
    for nAcq = 1:nAcqs
        if iscell(filesIn{nAcq})
            movName = filesIn{nAcq}{1};
        else
            movName = filesIn{nAcq};
        end
        acqName{nAcq} = movName(1:4);
    end
elseif length(acqName)~=nAcqs
    error('Improper formatting of Acquisition Object Names');
end

[copied, message] = copyfile(movPath,fileDest);
if ~copied
    error(message);
end

for nAcq = 1:nAcqs    
    fprintf('\n Processing Acquisition %02.0f of %02.0f\n',nAcq,nAcqs),
    acq = Acquisition2P(acqName{nAcq});
    acq.defaultDir = fileDest;
    acq.motionCorrectionFunction = @withinFile_segmentConsensus;
    if iscell(filesIn{nAcq})
        nFiles = length(filesIn{nAcq});
        for nFile = 1:nFiles
            acq = acq.populateMovieList(fullfile(movPath,filesIn{nAcq}{nFile}));
        end
    else
        acq = acq.populateMovieList(fullfile(movPath,filesIn{nAcq}));
    end
    acq = motionCorrect(acq);    
end

if ~copied
    error('File Transfer Failed')
elseif copied
    success = rmdir(movPath,'s');
    if ~success
        display('Files failed to be deleted locally'),
    end
end