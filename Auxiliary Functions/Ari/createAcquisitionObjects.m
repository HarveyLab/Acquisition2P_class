function createAcquisitionObjects(folder)
%createAcquisitionObjects.m Looks through folder and creates acquisition
%objects to be processed
%
%INPUTS
%folder - folder to look through 
%
%ASM 11/14

if nargin < 1 || isempty(folder)
    folder = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Ari\2P Data\ResScan';
end

%get subdirectories which match mouseName 
subDir = getSubDir(folder);
mouseDir = subDir(~cellfun(@isempty,regexp(subDir,'[A-Z]{2}\d\d\d$')));

%if no mouseDir, check for dateDir 
if isempty(mouseDir)
    dateDir = subDir(~cellfun(@isempty,regexp(subDir,'\d{6}$')));
    if isempty(dateDir) %if no date directories, invalid directory, throw error
        error('Invalid directory');
    else
        mouseDir = {folder};
    end
    
end

%get number of mouse directories
nMouseDir = length(mouseDir);

%loop through each mouse directory
for mouseInd = 1:nMouseDir
    
    %get list of date directories 
    mouseSubDir = getSubDir(mouseDir{mouseInd});
    dateDir = mouseSubDir(~cellfun(@isempty,regexp(mouseSubDir,'\d{6}$')));
    
    
    
    %loop through each date directory and create object
    for dateInd = 1:length(dateDir)
        
        %get acqName 
        fileParts = explode(dateDir{dateInd},filesep);
        acqName = sprintf('%s_%s',fileParts{end-1},fileParts{end});
        acqPath = sprintf('%s%s%s.mat',dateDir{dateInd},filesep,acqName);
        
        %check if acquisition object exists
        if exist(acqPath,'file')
            
            %load in object
            obj = load(acqPath);
            
            %check if roiInfo is filled in
            if ~isempty(obj.(acqName).roiInfo) %if not empty, continue and skip file
                continue;
            end
            
        end
        
        %Create object 
        Acquisition2P([],{@am2PInit,[],dateDir{dateInd}});

    end 
    
end

end

function subDir = getSubDir(folder)

%get list of folders and files
dirList = dir(folder);
dirList = {dirList(:).name};

%filter out movement dots
dirList = dirList(~ismember(dirList,{'.','..'}));

%append full path to dir 
dirList = cellfun(@(x) sprintf('%s%s%s',folder,filesep,x),dirList,'UniformOutput',false);

%filter out non-directories
subDir = dirList(cellfun(@isdir,dirList));
end