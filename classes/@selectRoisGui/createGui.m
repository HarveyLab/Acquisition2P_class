function createGui(sel, acq, img, sliceNum, channelNum, smoothWindow, excludeFrames)
% Constructor method for the selectRoisGui class. See selectROIs.m for
% usage.

%% For debugging:
% assignin('base', 'sel', sel);

%% Create GUI data structure:
% Initialize properties:
sel.acq = acq;
sel.slice = sliceNum;

% Set up roiInfo: The roiInfo property of the sel object automatically
% points to the acq object, so whatever we do to sel get's propagated to
% acq.
if ~isfield(sel.roiInfo, 'roi') || isempty(sel.roiInfo.roi)
    % If this is acq object has not been processed before, initialize
    % fields:
    [h, w, ~] = size(img);
    sel.roiInfo.hasBeenViewed = zeros(h, w);
    sel.roiInfo.roi = struct('id', [], 'group', [], 'indBody', [], ...
        'indNeuropil', [], 'subCoef', []);
end

% Create roiLabels:
sel.disp.roiLabels = zeros(size(img, 1), size(img, 2));
for roi = sel.roiInfo.roi(:)'
    sel.disp.roiLabels(roi.indBody(isfinite(roi.indBody))) = roi.id;
end

% Set the current ROI to be 1 greater than last selected
sel.disp.currentRoi = max([sel.roiInfo.roi.id])+1;

% Initialize data/settings for display:
sel.disp.clusterNum = 3; % Initial number of cuts.
sel.disp.currentClustering = zeros(sel.roiInfo.covFile.nh); % Labels of current clusters.
sel.disp.currentClustInd = []; % Which cluster/Roi is currently selected.
sel.disp.cutMod_nTopToExclude = 0;
sel.disp.cutVecs = [];
sel.disp.roiMask = [];
sel.disp.indBody = [];
sel.disp.indNeuropil = [];
sel.disp.neuropilCoef = [];
sel.disp.smoothWindow = smoothWindow;
sel.disp.currentPos = [nan nan]; % Makes current click/focus position available across functions.
sel.disp.isMouseOnRoiAx = false;
sel.disp.movSize = size(img);
sel.disp.excludeFrames = excludeFrames; % Frames in the traces that are to be excluded from neuropil calculations, e.g. due to stim artefacts.
sel.disp.roiColors =  [0 0 1;...
    1 0 0;
    0 1 0;...
    0 0 0.172413793103448;...
    1 0.103448275862069 0.724137931034483;...
    1 0.827586206896552 0;...
    0 0.344827586206897 0;...
    0.517241379310345 0.517241379310345 1;...
    0.620689655172414 0.310344827586207 0.275862068965517];

if isfield(sel.acq.metaDataSI,'SI4')
    sel.disp.framePeriod = sel.acq.metaDataSI.SI4.scanFramePeriod;
elseif isfield(sel.acq.metaDataSI,'SI5')
    sel.disp.framePeriod = sel.acq.metaDataSI.SI5.scanFramePeriod;
elseif isfield(sel.acq.metaDataSI,'SI')
    sel.disp.framePeriod = sel.acq.metaDataSI.SI.hRoiManager.scanFramePeriod;
else
    warning('Unable to Automatically determine scanFramePeriod')
    sel.disp.framePeriod = input('Input scanFramePeriod: ');
end


% Create overview image:
if size(img, 3) == 1
    % Img is a grayscale image:
    img = imadjust(img);
end
sel.disp.img = img;

% Create memory map of pixCov file:
if ~exist(sel.roiInfo.covFile.fileName, 'file')
    error('Cannot find covFile at path specified in acq2p object.');
end
sel.covMap = memmapfile(sel.roiInfo.covFile.fileName, ...
    'format', {'single', [sel.roiInfo.covFile.nPix, sel.roiInfo.covFile.nDiags], 'pixCov'});

% Create memory mapped binary file of movie:
movSizes = sel.acq.correctedMovies.slice(sliceNum).channel(channelNum).size;
movLengths = movSizes(:, 3);
if ~exist(acq.indexedMovie.slice(sliceNum).channel(channelNum).fileName, 'file')
    error('Cannot find binary movie file at path specified in acq2p object.');
end
sel.movMap = memmapfile(acq.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
    'Format', {'int16', [sum(movLengths), movSizes(1,1)*movSizes(1,2)], 'mov'});

%% Create GUI layout:
% Check if a GUI exists from a previous session and close it to prevent
% errors:
openFigs = findall(0, 'type', 'figure');
if ~isempty(openFigs)
    close(openFigs(ismember(get(openFigs, 'name'), 'ROI Selection')));
end

% Create main GUI figure:
sel.h.fig.main = figure('Name','ROI Selection');
set(sel.h.fig.main, 'DefaultAxesFontSize', 10);

% Layout is based on screen orientation:
screenSize = get(0,'screensize');
if screenSize(3) > screenSize(4)
    % Landscape-format screen:
    sel.h.ax.overview = subplot(4, 6, [3:6; 9:12; 15:18; 21:24]);
    sel.h.ax.eig(1) = subplot(4, 6, 1);
    sel.h.ax.eig(2) = subplot(4, 6, 7);
    sel.h.ax.eig(3) = subplot(4, 6, 13);
    sel.h.ax.eig(4) = subplot(4, 6, 19);
    sel.h.ax.eig(5) = subplot(4, 6, 14);
    sel.h.ax.eig(6) = subplot(4, 6, 20);
    sel.h.ax.cluster = subplot(4, 6, 2);
    sel.h.ax.roi = subplot(4, 6, 8);
    
    % Create sliders:
    refPos =  get(sel.h.ax.overview, 'Position'); %get refImage position
    sel.h.ui.sliderBlack = uicontrol('Style', 'slider', 'Units', 'Normalized',...
        'Position', [refPos(1)+0.075 refPos(2) - 0.05 .3*refPos(3) 0.02],...
        'Min', 0, 'Max', 1, 'Value', 0, 'SliderStep', [0.01 0.1],...
        'Callback',@sel.cbSliderContrast);
    sel.h.ui.sliderWhite = uicontrol('Style', 'slider', 'Units', 'Normalized',...
        'Position', [refPos(1)+0.35 refPos(2) - 0.05 .3*refPos(3) 0.02],...
        'Min', 0, 'Max', 1, 'Value', 1, 'SliderStep', [0.01 0.1],...
        'Callback',@sel.cbSliderContrast);
else
    % Portrait-format screen:
    sel.h.ax.overview = subplot(6, 4, 9:24);
    sel.h.ax.eig(1) = subplot(6, 4, 1);
    sel.h.ax.eig(2) = subplot(6, 4, 2);
    sel.h.ax.eig(3) = subplot(6, 4, 3);
    sel.h.ax.eig(4) = subplot(6, 4, 4);
    sel.h.ax.eig(5) = subplot(6, 4, 7);
    sel.h.ax.eig(6) = subplot(6, 4, 8);
    sel.h.ax.cluster = subplot(6, 4, 5);
    sel.h.ax.roi = subplot(6, 4, 6);

end

% Create auto-cut calculation checkboxes
sel.h.ui.autoCalcCuts = uicontrol('Style', 'checkbox','String','Estimate Cuts',...
    'Units', 'Normalized', 'Position', [0.034 0.02 0.15 0.048]);
sel.h.ui.autoCalcClusters = uicontrol('Style', 'checkbox','String','Estimate Clusters',...
    'Units', 'Normalized', 'Position', [0.034 0.05 0.15 0.048]);

%create traces figures
sel.h.fig.trace(1) = figure('Name','Cluster Traces');
sel.h.ax.traceClusters = axes;
sel.h.ui.autoLoadTraces = uicontrol('Style', 'checkbox','String','Auto Load',...
    'Units', 'Normalized', 'Position', [0.034 0.02 0.15 0.048]);
sel.h.fig.trace(2) = figure('Name','Raw Trace Overlays');
sel.h.ax.traceOverlay = axes;
hold(sel.h.ax.traceOverlay, 'on'),
sel.h.fig.trace(3) = figure('Name','Neuropil-sub Traces');
sel.h.ax.traceSub = axes;
sel.h.ui.plotRaw = uicontrol('Style', 'checkbox','String','Raw Plot',...
    'Callback', @sel.doSubTracePlot, 'Units', 'Normalized', 'Position',...
    [0.034 0.02 0.15 0.048]);
sel.h.fig.trace(4) = figure('Name','Neuropil-sub Scatter');
sel.h.ax.subSlope = axes;
drawnow
setFigDockGroup(sel.h.fig.trace,'tracePlotsGUI')
set(sel.h.fig.trace,'WindowStyle','docked');

% Switch off UI tools for all figures (some callbacks can only be added if
% no tool is selected):
activateuimode(sel.h.fig.main, '');
for i = 1:numel(sel.h.fig.trace)
    activateuimode(sel.h.fig.trace(i), '');
end

% Set callbacks:
set(sel.h.fig.main, 'WindowButtonDownFcn', @sel.cbMouseclick, ...
    'WindowButtonMotionFcn', @sel.cbMousemove, ...
    'WindowScrollWheelFcn', @sel.cbScrollwheel, ...
    'WindowKeyPressFcn', @sel.cbKeypress, ...
    'CloseRequestFcn', @sel.cbCloseRequestMain)
set(sel.h.fig.trace(4), 'WindowScrollWheelFcn', @sel.subCoefScrollWheel, ...
    'WindowKeyPressFcn', @cbPassThroughKeypressToMain, ...
    'WindowButtonMotionFcn', @cbFocusFollowsMouse)
set(sel.h.fig.trace(:), 'WindowKeyPressFcn', @sel.cbKeypressTraceWin, ...
    'WindowKeyPressFcn', @sel.cbPassThroughKeypressToMain, ...
    'CloseRequestFcn', @sel.cbCloseRequestMain)

% Set up timers (they can be used to do calculations in the background to
% improve perceived responsiveness of the GUI):
sel.h.timers.loadTraces = timer('name', 'selectRoisGui:loadTraces', ...
    'timerfcn', @(~, ~) sel.cbKeypress([], struct('Key', 'f')), 'executionmode', 'singleshot', 'busymode', 'drop', 'StartDelay', 0.2);

%% Draw images and store image handles:
% Reason: If we have image handles, we can save time by directly updating
% the image cdata, rather than redrawing the entire axis:

% Overview image:
sel.h.img.overview = imagesc(sel.disp.img, 'parent', sel.h.ax.overview);
set(sel.h.ax.overview, 'dataaspect', [1 1 1]);
set(sel.h.ax.overview,'XTick', [], 'YTick', [], 'XTickLabel', [], 'YTickLabel', []); %turn off ticks
colormap(sel.h.ax.overview, 'gray'); %set colormap to gray
title(sel.h.ax.overview, 'Overview')

% "Has been viewed" overlay:
if size(sel.disp.img, 3) == 3
    % Overview image is colored: Show outlines of "has been viewed" in
    % gray:
    hasBeenViewedColor = repmat(permute([0; 0; 0], [2 3 1]), sel.disp.movSize(1), sel.disp.movSize(2));
else
    % Grayscale image: show "has been viewed" area in red:
    hasBeenViewedColor = repmat(permute([1; 0.3; 0.6], [2 3 1]), sel.disp.movSize(1), sel.disp.movSize(2));
end
hold(sel.h.ax.overview, 'on')
sel.h.img.hasBeenViewed = imshow(hasBeenViewedColor, 'Parent', sel.h.ax.overview);
hold(sel.h.ax.overview, 'off')

% Eigenvector images:
for ii = 1:numel(sel.h.ax.eig)
   sel.h.img.eig(ii) = imshow(zeros(sel.roiInfo.covFile.nh), 'Parent', sel.h.ax.eig(ii));
end

% Cluster image:
sel.h.img.cluster = imshow(zeros(sel.roiInfo.covFile.nh), 'Parent', sel.h.ax.cluster);

% ROI overlay image:
sel.h.img.roi = imshow(zeros(sel.roiInfo.covFile.nh), 'Parent', sel.h.ax.roi);

% Draw everything:
sel.updateOverviewDisplay;

% Maximize figure window:
warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame'); %disable java warning
jFrame = get(sel.h.fig.main, 'JavaFrame');
drawnow % Required for maximization to work.
jFrame.setMaximized(1);

function cbFocusFollowsMouse(~, evt, ~)
% Attach this function as the WindowButtonMotionFcn callback to any figure
% that you want to be in focus whenever the mouse cursor is above that
% figure.
if ~isequal(gcf, evt.Source)
    figure(evt.Source)
end
