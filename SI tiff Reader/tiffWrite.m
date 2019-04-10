function tiffWrite(img, fileName, filePath, option, isSilent)
% tiffWrite(img, fileName, filePath, option, isSilent)

if ~isa(img, 'numeric')
    error('First argument must be numeric (image to save).');
end

if ~exist('fileName', 'var') || isempty(fileName)
    fileName = inputname(1);
end

if ~exist('filePath', 'var') || isempty(filePath)
    filePath = cd;
end

if ~exist('option', 'var')
    option = 'uint16';
end

if ~exist('isSilent', 'var') || isempty(isSilent)
    isSilent = false;
end

% Add extension:
if isempty(regexp(fileName, '\.tiff?$', 'ignorecase'))
    fileName = [fileName, '.tif'];
end

% Create folder if necessary:
if exist(filePath, 'dir') ~= 7
    mkdir(filePath);
end

% Create Tiff object:
if strcmp(option, 'append')
    if ~exist(fullfile(filePath, fileName), 'file')
        error('File to be appended on does not exist.')
    end
    
    t = Tiff(fullfile(filePath, fileName), 'r+');
    option = t.getTag('BitsPerSample');
    
    % Check for consistency:
    if ~strcmp(t.getTag('Software'), ['MATLAB:' mfilename])
        warning('The file to which data is to be appended was not written by this MATLAB function. Unexpected outcomes might result.');
    end
    
    if t.getTag('ImageLength') ~= size(img, 1)
        error('Image to be appended does not match length of tiff image.');
    end
    if t.getTag('ImageWidth') ~= size(img, 2)
        error('Image to be appended does not match length of tiff image.');
    end
    
    % Write directory for first appended frame:
    t.writeDirectory();
    
else
    t = Tiff(fullfile(filePath, fileName), 'w');
end

% Convert input image to desired bitDepth:
switch option
    case 'uint8'
        img = uint8(img);
        tagStruct.SampleFormat = 1;
        tagStruct.BitsPerSample = 8;
    case 'uint16'
        img = uint16(img);
        tagStruct.SampleFormat = 1;
        tagStruct.BitsPerSample = 16;
    case 'uint32'
        img = uint32(img);
        tagStruct.SampleFormat = 1;
        tagStruct.BitsPerSample = 32;
    case 'int8'
        img = int8(img);
        tagStruct.SampleFormat = 2;
        tagStruct.BitsPerSample = 8;
    case 'int16'
        img = int16(img);
        tagStruct.SampleFormat = 2;
        tagStruct.BitsPerSample = 16;
    case 'int32'
        img = int32(img);
        tagStruct.SampleFormat = 2;
        tagStruct.BitsPerSample = 32;
    otherwise
        error('Unsupported bit depth.');
end

% Get size
[h, w, z] = size(img);

% Set tiff tags:
tagStruct.ImageLength = h;
tagStruct.ImageWidth = w;
tagStruct.Photometric = Tiff.Photometric.MinIsBlack;
tagStruct.SamplesPerPixel = 1;
tagStruct.Compression = 1;
tagStruct.Software = ['MATLAB:' mfilename];
tagStruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
t.setTag(tagStruct);

% Write all frames:
t.write(img(:,:,1)); % First frame;

for i = 2:z
    t.writeDirectory();
    t.setTag(tagStruct);
    t.write(img(:,:,i));
    if ~isSilent && ~mod(i, 200)
        fprintf('%1.0f frames written.\n', i);
    end
end

t.close();