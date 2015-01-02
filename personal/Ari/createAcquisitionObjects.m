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

%in progress directory 
inProgressDir = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Ari\2P Data\ResScan\Acq2PToProcess\inProgress';
inQueueDir = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Ari\2P Data\ResScan\Acq2PToProcess';

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
        acqPath = sprintf('%s%s%s_acq.mat',dateDir{dateInd},filesep,acqName);
        acqStatusPath = sprintf('%s%s%s_status.txt',dateDir{dateInd},filesep,acqName);
        inProgressPath = sprintf('%s%s%s_acq.mat',inProgressDir,filesep,acqName);
        inQueuePath = sprintf('%s%s%s_acq.mat',inQueueDir,filesep,acqName);
        
        if exist(acqStatusPath,'file')
            
            %                 obj = load(acqPath);
            %
            %                 neighborhoodConstant = 1.5;
            %                 if isfield(obj.(acqName).derivedData(1),'SIData')
            %                     if isfield(obj.(acqName).derivedData(1).SIData,'SI4')
            %                         objectiveMag = 25;
            %                         zoomFac = obj.(acqName).derivedData(1).SIData.SI4.scanZoomFactor;
            %                     elseif isfield(obj.(acqName).derivedData(1).SIData,'SI5')
            %                         objectiveMag = 16;
            %                         zoomFac = obj.(acqName).derivedData(1).SIData.SI5.zoomFactor;
            %                     end
            %                     pxCovRad = round(objectiveMag*zoomFac/neighborhoodConstant);
            %                 else
            %                     pxCovRad = [];
            %                 end
            %
            %                 if obj.(acqName).roiInfo.slice(1).covFile.nh ~= (pxCovRad*2 + 1)
            %                     delete(acqStatusPath);
            %                     fprintf('Deleted %s\n',acqPath);
            %                     obj.(acqName).roiInfo = [];
            %                     shouldProcFolder = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Ari\2P Data\ResScan\Acq2PToProcess';
            %                     eval(sprintf('%s=obj;',acqName));
            %                     save(sprintf('%s%s%s_acq.mat',shouldProcFolder,filesep,acqName),acqName);
            %                 end
            
            
            continue;
        end
        
        %check if acquisition currently in progress || in queue
        if exist(inProgressPath, 'file') || exist(inQueuePath, 'file')
            continue;
        end
        
        %check if acquisition object exists
        if exist(acqPath,'file')           
            
            %load in object
            obj = load(acqPath);
            
            %check if roiInfo is filled in
            if ~isempty(obj.(acqName).roiInfo) %if not empty, continue and skip file
                writeStatusFile(acqStatusPath, 'Complete');
                continue;
            end
            
        end
        
        %Create object
        obj = Acquisition2P([],{@am2PInit,[],dateDir{dateInd}});
        
        %if no movies, save status file
        if isempty(obj.Movies)
            writeStatusFile(acqStatusPath,'No Movies');
        end
        
    end
    
end

end

function writeStatusFile(acqStatusPath, writeStr)
    %create status file
    fid = fopen(acqStatusPath,'w');
    fprintf(fid,writeStr);
    fclose(fid);
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