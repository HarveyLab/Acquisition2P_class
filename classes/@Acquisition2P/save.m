function save(obj,writeDir,writeName,varName)
% Saves the acquisition object. By default uses defaultDir as writeDir and 
% acqName as both writeName and varName
% 
% save(obj,writeDir,writeName,varName)
%
% writeDir is the directory to save the acq in
% writeName is the filename to save the acq as
% varName is the variable name the acq is represented by within the mat file

if ~exist('writeDir','var') || isempty(writeDir)
    writeDir = obj.defaultDir;
end

if ~exist('writeName','var') || isempty(writeName)
    writeName = obj.acqName;
end

if ~exist('varName','var') || isempty(varName)
    varName = obj.acqName;
end

% Make sure that varName is an allowed variable name:
if verLessThan('matlab', '8.3')
    varName = genvarname(varName); %#ok<DEPGENAM>
else
    varName = matlab.lang.makeValidName(varName);
end

eval([varName ' = obj;']),
save(fullfile(writeDir,writeName),varName)

end