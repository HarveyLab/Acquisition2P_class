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

%change to folder 
origDir = dir(folder);

%get list of subdirectories
subFolders = 