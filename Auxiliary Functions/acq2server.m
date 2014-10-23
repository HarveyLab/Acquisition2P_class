function success = acq2server(obj,fileDest)
%Example auxilliary function to transfer all files in an acq's default
%directory to the server, perform motion correction, then transfer the
%acquisition and motion corrected data to the server

%obj is the acquisition object
%fileDest is optional and should be a string specifying the write directory

%% Input handling and default directory / auto-naming
if ~exist('fileDest','var')
    fileDest = [];
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
[copied, message] = copyfile(movPath,fileDest);
if ~copied
    error(message);
end

obj.motionCorrect;
obj.newDir(fileDest);

if copied
    success = rmdir(movPath,'s');
    if ~success
        display('Files failed to be deleted locally'),
    end
end