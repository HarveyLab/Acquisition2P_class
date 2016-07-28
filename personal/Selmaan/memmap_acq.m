function data = memmap_acq(obj,nSlice)

% read a sequence of stacked tiff arrays, reshapes it to 2d array and saves it a mat file that can be memory mapped. 
% The file is saved both in its original format and as a reshaped 2d matrix

% INPUTS
% foldername:     path to tiff folder containing a series of tiff files

% OUTPUT
% data:         object with the data containing:
%   Yr:         reshaped data file
% sizY:         dimensions of original size
%   nY:         minimum value of Y (not subtracted from the dataset)

% Author: Eftychios A. Pnevmatikakis, Simons Foundation, 2016

nY = Inf;
files = obj.correctedMovies.slice(nSlice).channel(1).fileName;
T = 0;
dataFileName = [obj.defaultDir,obj.acqName,sprintf('_memmap_slice%02d',nSlice),'.mat'];
data = matfile(dataFileName,'Writable',true);
% tt1 = tic;
for i = 1:length(files)
    fprintf('File %0.3d of %0.3d \n',i,length(files)),
    filename = files{i};
    Y = tiffRead(filename,'int16');
    sizY = size(Y);
    Yr = reshape(Y,prod(sizY(1:end-1)),[]);
    nY = min(min(Yr(:)),nY);
    if length(sizY) == 3
        data.Y(1:sizY(1),1:sizY(2),T+(1:size(Yr,2))) = Y;        
    elseif legnth(sizY) == 4
        data.Y(1:sizY(1),1:sizY(2),1:sizY(3),T+(1:size(Yr,2))) = Y;
    end
    data.Yr(1:prod(sizY(1:end-1)),T+(1:size(Yr,2))) = Yr;
    T = sizY(end) + T;
%     toc(tt1);
end
sizY(end) = T;
data.sizY = sizY;
data.nY = nY;
obj.indexedMovie.memMap.slice(nSlice).fn = data.Properties.Source;
% obj.save,