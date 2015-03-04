function SCsc(obj)
%Example of an Acq2P Initialization Function. Allows user selection of
%movies to form acquisition, sorts alphabetically, assigns an acquisition
%name and default directory, and assigns the object to a workspace variable
%named after the acquisition name

%Initialize user selection of multiple tif files
[movNames, movPath] = uigetfile('*.tif','MultiSelect','on');

%Set default directory to folder location,
obj.defaultDir = movPath;

%sort movie order alphabetically for consistent results
movNames = sort(movNames);

%Attempt to automatically name acquisition from movie filename, raise
%warning and create generic name otherwise
try
    acqNamePlace = find(movNames{1} == '_',1);
    obj.acqName = movNames{1}(1:acqNamePlace-1);
catch
    obj.acqName = sprintf('%s_%.0f',date,now);
    warning('Automatic Name Generation Failed, using date_time')
end

%Attempt to add each selected movie to acquisition in order
for nMov = 1:length(movNames)
    obj.addMovie(fullfile(movPath,movNames{nMov}));
end

%Automatically fill in fields for motion correction
obj.motionRefMovNum = floor(length(movNames)/2);
obj.motionRefChannel = 1;
obj.binFactor = 1;
obj.motionCorrectionFunction = @withinFile_segmentConsensus;

%Assign acquisition object to acquisition name variable in workspace
assignin('base',obj.acqName,obj);

%Notify user of success
fprintf('Successfully added %03.0f movies to acquisition: %s\n',length(movNames),obj.acqName),