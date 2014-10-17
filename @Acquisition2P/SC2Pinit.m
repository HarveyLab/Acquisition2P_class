function SC2Pinit(obj)

%Example of an Acq2P Initialization Function. Allows user selection of
%movies to form acquisition, sorts alphabetically, assigns an acquisition
%name and default directory, and assigns the object to a workspace variable
%named after the acquisition name

[movNames, movPath] = uigetfile('*.tif','MultiSelect','on');
obj.defaultDir = movPath;
movNames = sort(movNames);
acqNamePlace = find(movNames{1} == '_',1);
obj.acqName = movNames{1}(1:acqNamePlace-1);
for nMov = 1:length(movNames)
    obj.addMovie(fullfile(movPath,movNames{nMov}));
end
obj.motionRefMovNum = floor(length(movNames)/2);
obj.motionRefChannel = 1;
obj.binFactor = 1;
obj.motionCorrectionFunction = @withinFile_segmentConsensus;

assignin('base',obj.acqName,obj);
fprintf('Successfully added %03.0f movies to acquisition: %s\n',length(movNames),obj.acqName),