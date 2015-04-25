function playMov(mov)

mov = downsampleWithAvg(mov, 10);

% Display figure:
[h, w, z] = size(mov);
hFig = figure(4852898);
clf
set(hFig, 'name', sprintf('1/%d; %dx%d pixels', z, h, w));
hAxMain = axes;

mov = mov.^0.25;
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
% movBlurred = imgGaussBlur(mov, 1.5);
movBlurred = mov;
movBlurred = bsxfun(@rdivide, movBlurred, mean(mean(movBlurred, 1), 2));
set(hFig, 'WindowButtonDownFcn', {@cbMouseclick, hAxMain, hSlider, movBlurred});


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



