function addCorrMovies(obj,nSlice,nChannel)
%Example of an Acq2P Initialization Function. Allows user selection of
%movies to form acquisition, sorts alphabetically, assigns an acquisition
%name and default directory, and assigns the object to a workspace variable
%named after the acquisition name

if ~exist('nSlice','var') || isempty(nSlice)
    nSlice = 1;
end

if ~exist('nChannel','var') || isempty(nChannel)
    nChannel = 1;
end

%Initialize user selection of multiple tif files
[movNames, movPath] = uigetfile(fullfile(obj.defaultDir,'*.tif'),'MultiSelect','on');

%Set default directory to folder location, in case this changed
obj.defaultDir = movPath;

%sort movie order alphabetically for consistent results
movNames = sort(movNames);

%Fill in appropriate fields of acquisition object
for nMov = 1:length(movNames)
    obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{nMov} = ...
        fullfile(movPath,movNames{nMov});
end

%Notify user of success
fprintf('Successfully added %03.0f movies to acquisition: %s\n',length(movNames),obj.acqName),