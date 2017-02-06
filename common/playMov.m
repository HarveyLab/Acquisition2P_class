function playMov(mov)
% playMov(mov) displays a H-by-W-by-nFrames array as a movie, similar to
% ImageJ. Clicking any spot in the image jumps to the frame at which the
% clicked point is brightest. 
%
% To do:
% - Implement play button
% - align activity trace to slider.

mov = downsampleWithAvg(mov, 10);

% Display figure:
[h, w, z] = size(mov);
hFig = figure(4852898);
clf
set(hFig, 'name', sprintf('1/%d; %dx%d pixels', z, h, w));
hAxMain = axes;

mov = max(mov, 0).^0.25;
scale = quantile(mov(:), [0.05, 0.99995]);
hImg = imagesc(mov(:,:,1), [scale(1), scale(2)]);
colormap(hAxMain, gray);
hFig.UserData = mov;

hAxTrace = axes;
imagesc(mean(reshape(mov, [], z)));
colormap(hAxTrace, parula);

% Format layout:
hFig.MenuBar = 'none';
hAxMain.Box = 'off';
hAxMain.XColor = 'w';
hAxMain.YColor = 'w';
hAxMain.Units = 'normalized';
sliderHeight = 0.05;
hAxMain.Position = [0 2*sliderHeight 1 1];
hAxMain.DataAspectRatio = [1 1 1];
hAxMain.XTick = [];
hAxMain.YTick = [];

hAxTrace.Position = [sliderHeight sliderHeight 1-sliderHeight 2*sliderHeight];
hAxTrace.XTick = [];
hAxTrace.YTick = [];
hAxTrace.Box = 'off';
hAxTrace.XColor = 'w';
hAxTrace.YColor = 'w';

% Create slider:
hSlider = uicontrol('style','slider', ...
    'units', 'normalized', ...
    'position', [sliderHeight 0 1-sliderHeight sliderHeight], ...
    'parent', hFig, ...
    'SliderStep', [1/z, 1/100]);
jScrollBar = findjobj(hSlider);
jScrollBar.AdjustmentValueChangedCallback = {@cbSlider, hFig, hImg};

% Create play button:
hButtonPlay = uicontrol('style','pushbutton', ...
    'units', 'normalized', ...
    'position', [0 0 sliderHeight sliderHeight], ...
    'parent', hFig, ...
    'ButtonDownFcn', {@cbPlay, hFig, hImg}, ...
    'Enable', 'off');

% Create main window mouse click callback
% (Click jumps to brightest spot)
mov = bsxfun(@rdivide, mov, mean(mean(mov, 1), 2));
set(hFig, 'WindowButtonDownFcn', {@cbMouseclick, hAxMain, hSlider, mov});


function cbSlider(src, evt, hFig, hImg)
sliderPos = (evt.getValue-src.Minimum)/src.Maximum; % Java reports the slider pos in weird units.
mov = hFig.UserData;
[h, w, z] = size(mov);
nFrames = size(mov, 3);
f = round((nFrames-1)*sliderPos)+1;
hImg.CData = mov(:,:,f);
hFig.Name = sprintf('%d/%d; %dx%d pixels', f, z, h, w);

function cbPlay(src, evt, hFig, hImg)
disp('play')

function cbMouseclick(src, evt, hAxMain, hSlider, mov)
cp = round(get(hAxMain,'currentpoint'));
[~, maxInd] = max(mov(cp(3), cp(1), :));
jScrollBar = findjobj(hSlider);
movPos = maxInd/size(mov, 3);
jScrollBar.setValue(movPos*jScrollBar.Maximum+jScrollBar.Minimum);

function mov = downsampleWithAvg(mov, fDown)
% downsampleWithAvg reduces the number of frames in movie MOV by the factor
% FDOWN, by averaging blocks of successive frames.

if fDown < 0 || fDown - round(fDown) ~= 0 || fDown > size(mov,3)
	error('Downsampling factor must be a positive integer between 1 and the number of frames in mov.');
end

% Truncate movie such that the number of frames is evenly divisible by
% fDown
mov = mov(:,:,1:end-mod(size(mov,3),fDown));

[h, w, z] = size(mov);

% Reshape movie for averaging:
mov = reshape(mov, h, w, fDown, z/fDown);

% Average along fourth dimension
mov = squeeze(mean(mov, 3));