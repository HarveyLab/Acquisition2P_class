function am2PInit(obj,movPath)
%Example of an Acq2P Initialization Function. Allows user selection of
%movies to form acquisition, sorts alphabetically, assigns an acquisition
%name and default directory, and assigns the object to a workspace variable
%named after the acquisition name


if nargin < 2 || isempty(movPath) %if no folder provided
    
    %Initialize user selection of multiple tif files
    %     [movNames, movPath] = uigetfile('*.tif','MultiSelect','on');
    movPath = uigetdir('\\research.files.med.harvard.edu\Neurobio\HarveyLab\Ari\2P Data\ResScan');
end

%Set default directory to folder location,
obj.defaultDir = movPath;

%get movNames
movNames = dir([movPath,filesep,'*.tif']);
movNames = {movNames(:).name};

%sort movie order alphabetically for consistent results
movNames = sort(movNames);

%Attempt to automatically name acquisition from movie filename, raise
%warning and create generic name otherwise
try
    fileStrings = explode(movPath,filesep);
    nFileStrings = length(fileStrings);
    dateStr = fileStrings{nFileStrings};
    mouseName = fileStrings{nFileStrings-1};
    if isempty(regexp(dateStr,'\d{6}','ONCE')) || isempty(regexp(mouseName,'AM\d{3}','ONCE'))
        error('Can''t process name');
    end
    obj.acqName = sprintf('%s_%s',mouseName,dateStr);
catch
    obj.acqName = sprintf('%s_%.0f',date,now);
    warning('Automatic Name Generation Failed, using date_time')
end

%look for previous acquisition object
prevAcqFileName = sprintf('%s%s%s.mat',movPath,filesep,obj.acqName);
if exist(prevAcqFileName,'file')
    tempObj = load(prevAcqFileName,obj.acqName);
    obj = copyObj(obj,tempObj.(obj.acqName));
    
    %Assign acquisition object to acquisition name variable in workspace
    assignin('base',obj.acqName,obj);
    return;
end

%remove processed files
movNames = movNames(~cellfun(@isempty,regexp(movNames,'[A-Z]{2}\d{3}_\d{3}_\d{3}.tif')));

%Attempt to add each selected movie to acquisition in order
% for nMov = 1:length(movNames)
%     obj.addMovie(fullfile(movPath,movNames{nMov}));
% end
obj.Movies = cellfun(@(x) sprintf('%s%s%s',movPath,filesep,x),movNames,'UniformOutput',false);

%Automatically fill in fields for motion correction
obj.motionRefMovNum = ceil(length(movNames)/2);
obj.motionRefChannel = 2; %red channel should be used for motion correction
obj.binFactor = 1;
obj.motionCorrectionFunction = @withinFile_withinFrame_lucasKanade;

%fill in date
obj.dateCreated = date;

%Assign acquisition object to acquisition name variable in workspace
assignin('base',obj.acqName,obj);

%Copy acquisition object to should process folder
shouldProcFolder = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Ari\2P Data\ResScan\Acq2PToProcess';
eval(sprintf('%s=obj',obj.acqName));
save(sprintf('%s%s%s.mat',shouldProcFolder,filesep,obj.acqName),obj.acqName);

%Notify user of success
fprintf('Successfully added %03.0f movies to acquisition: %s\n',length(movNames),obj.acqName);

end

function [split,numpieces]=explode(string,delimiters)
%EXPLODE    Splits string into pieces.
%   EXPLODE(STRING,DELIMITERS) returns a cell array with the pieces
%   of STRING found between any of the characters in DELIMITERS.
%
%   [SPLIT,NUMPIECES] = EXPLODE(STRING,DELIMITERS) also returns the
%   number of pieces found in STRING.
%
%   Input arguments:
%      STRING - the string to split (string)
%      DELIMITERS - the delimiter characters (string)
%   Output arguments:
%      SPLIT - the split string (cell array), each cell is a piece
%      NUMPIECES - the number of pieces found (integer)
%
%   Example:
%      STRING = 'ab_c,d,e fgh'
%      DELIMITERS = '_,'
%      [SPLIT,NUMPIECES] = EXPLODE(STRING,DELIMITERS)
%      SPLIT = 'ab'    'c'    'd'    'e fgh'
%      NUMPIECES = 4
%
%   See also IMPLODE, STRTOK
%
%   Created: Sara Silva (sara@itqb.unl.pt) - 2002.04.30

if isempty(string) % empty string, return empty and 0 pieces
    split{1}='';
    numpieces=0;
    
elseif isempty(delimiters) % no delimiters, return whole string in 1 piece
    split{1}=string;
    numpieces=1;
    
else % non-empty string and delimiters, the correct case
    
    remainder=string;
    i=0;
    
    while ~isempty(remainder)
        [piece,remainder]=strtok(remainder,delimiters);
        i=i+1;
        split{i}=piece;
    end
    numpieces=i;
    
end
end

function obj = copyObj(obj,newObj)

%get list of properties
propertyList = properties(obj);


%loop through and replace
for propInd = 1:length(propertyList)
    obj.(propertyList{propInd}) = newObj.(propertyList{propInd});
end
end
