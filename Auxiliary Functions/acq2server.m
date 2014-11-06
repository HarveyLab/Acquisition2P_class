function success = acq2server(obj,fileDest,rawTransfer)
%Example auxilliary function to transfer all files in an acq's default
%directory to the server, perform motion correction, then transfer the
%acquisition and motion corrected data to the server

%obj is the acquisition object
%fileDest is optional and should be a string specifying the write directory
%rawTransfer is an optional logical, indicating whether to send raw as well
%as processed/corrected data to server

%% Input handling and default directory / auto-naming
if ~exist('fileDest','var')
    fileDest = [];
end

if ~exist('rawTransfer','var')
    rawTransfer = 1;
end

movPath = obj.defaultDir;
defReadDir = 'C:\Data';
defWriteDir = 'Z:\HarveyLab\Selmaan';
if isempty(fileDest)
    try
        fileDest = [defWriteDir movPath(length(defReadDir)+strfind(movPath,defReadDir):end)];
    catch
        error('No destination provided and default cannot be constructed')
    end
end

%% Transfer files and motion correction
if rawTransfer
    display('Copying Files to Server'),
    [copied, message] = copyfile(movPath,fileDest,'f');
    if ~copied
        error(message);
    end
else
    display('Not Copying raw data to server'),
    copied = 1;
end

obj.motionCorrect;
obj.newDir(fileDest);

if copied
    success = rmdir(movPath,'s');
    if ~success
        warning('Files failed to be deleted locally'),
    end
end