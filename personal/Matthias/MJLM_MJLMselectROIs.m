function MJLMselectROIs(obj, img, sliceNum, channelNum, smoothWindow, excludeFrames)
%selectROIs(obj,img,sliceNum,channelNum,smoothWindow)
%all inputs except acquisition object are optional
%
%GUI for sorting through seeds / pixel-pixel correlation matrices to select
%appropriate ROIs for an acquisition. Requires precalculated pixel
%covariance file generated by calcSeedCov, and advised to have 'indexed'
%binary file representation of movie as well for rapid trace loading

%img - the reference image used to select spatial regions, but is not used
    %in the actual calculation of ROIs or neuropil (i.e. you can do whatever
    %you want to it and it wont screw up cell selection). defaults to the
    %square root of the mean image, processed with local adaptive histogram equalization
%smoothWindow - the length (not std!) of gaussian kernel used to smooth traces for
    %display and for fitting neuropil subtraction coefficients (standard
    %deviation of gaussian window equals smoothWindow / 5)

% Click on reference image to select a seed region for pixel clustering
% Use scroll wheel to adjust # of clusters in current region
% Use 'tab' to cycle currently selected ROI through all clusters 
% Use 'f' to view (and compare) traces from multiple ROIs (in figure 783)
% Use 'space' to select and evaluate cell body-neuropil pairings (in figures 784-786)
% Use '1'-'9' to save an ROI or pairing w/ the corresponding numbered group
% Use 'backspace' to delete the last saved ROI
% Use 'm' to initiate manual drawing of polygon ROI (adds polygon to current clustering results)

%% Error checking and input handling
if ~exist('img','var') || isempty(img)
    img = obj.meanRef;
    img(img<0) = 0;
    img(isnan(img)) = 0;
    img = sqrt(img);
    img = adapthisteq(img/max(img(:)));
end
if ~exist('sliceNum','var') || isempty(sliceNum)
    sliceNum = 1;
end
if ~exist('channelNum','var') || isempty(channelNum)
    channelNum = 1;
end
if ~exist('smoothWindow','var') || isempty(smoothWindow)
    smoothWindow = 15;
end
if ~exist('excludeFrames','var')
    excludeFrames = [];
end

if isempty(obj.roiInfo)
    error('no ROI info is associated with this Acquisition')
elseif ~isfield(obj.roiInfo.slice(sliceNum),'covFile')
    error('Pixel-Pixel correlation matrix has not been calculated')
end

if isempty(obj.indexedMovie)
    warning('No indexed movie is associated with this Acquisition. Attempting to load traces will throw an error'),
end

%% Initialize gui data structure
gui = struct;
%Normalize image and add color channels
img = (img-prctile(img(:),1));
img = img/prctile(img(:),99);
gui.movSize = size(img);
gui.img = repmat(img,[1 1 3]);
% Grab roiInfo from object, and initialize new roi labels/list if needed
gui.roiInfo = obj.roiInfo.slice(sliceNum);
if ~isfield(gui.roiInfo,'roiList') || isempty(gui.roiInfo.roiList)
    %If this is acq object has not been processed before, initialize fields
    gui.roiInfo.roiLabels = zeros(size(img));
    obj.roiInfo.slice(sliceNum).roiLabels = [];
    obj.roiInfo.slice(sliceNum).roiList = [];
    obj.roiInfo.slice(sliceNum).grouping = [];
    obj.roiInfo.slice(sliceNum).roi = struct;
end
gui.roiInfo.roiList = unique(gui.roiInfo.roiLabels(:));
% Set the current ROI to be 1 greater than last selected
gui.cROI = max(gui.roiInfo.roiList)+1;
gui.roiInfo.roiList(gui.roiInfo.roiList==0) = [];
gui.roiColors = lines(30);
gui.hasBeenViewed = false(gui.movSize);

% Initialize cell/cluster fields:
gui.clusterNum = 3;
gui.traceF = [];
gui.indBody = [];
gui.indNeuropil = [];
gui.roiInd = [];

% Specify slice and channel gui correponds to, and pass handles to the
% appropriate acquisition object and pixel-pixel covariance matrix
gui.sliceNum = sliceNum;
gui.channelNum = channelNum;
gui.smoothWindow = smoothWindow;
gui.hAcq = obj;
gui.currentPos = [nan nan]; % Makes current click/focus position available across functions.

% Create memory map of pixCov file:
gui.covFile.map = memmapfile(gui.roiInfo.covFile.fileName, ...
    'format', {'single', [gui.roiInfo.covFile.nPix, gui.roiInfo.covFile.nDiags], 'pixCov'});
gui.covFile.radiusPxCov = (gui.roiInfo.covFile.nh-1)/2; % "Radius" is a historical term, more like "square edge half-length" now.

% Create memory mapped binary file of movie:
movSizes = [obj.derivedData.size];
movLengths = movSizes(3:3:end);
gui.movMap = memmapfile(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
    'Format', {'int16', [sum(movLengths), movSizes(1)*movSizes(2)], 'mov'});
gui.excludeFrames = excludeFrames; % Frames in the traces that are to be excluded from neuropil calculations, e.g. due to stim artefacts.

%% Create GUI figure
gui.hFig = figure;
set(gui.hFig, 'DefaultAxesFontSize', 10);

%Layout is based on screen size
screenSize = get(0,'screensize');
if screenSize(3) > screenSize(4)
    gui.hAxRef = subplot(4, 6, [3:6; 9:12; 15:18; 21:24]);
    gui.hEig1 = subplot(4,6,1);
    gui.hEig2 = subplot(4,6,7);
    gui.hEig3 = subplot(4,6,13);
    gui.hEig4 = subplot(4,6,19);
    gui.hEig5 = subplot(4,6,14);
    gui.hEig6 = subplot(4,6,20);
    gui.hAxClus = subplot(4, 6, 2);
    gui.hAxROI = subplot(4, 6, 8);    
else
    gui.hAxRef = subplot(6, 4, 9:24);
    gui.hEig1 = subplot(6, 4,1);
    gui.hEig2 = subplot(6, 4,2);
    gui.hEig3 = subplot(6, 4,3);
    gui.hEig4 = subplot(6, 4,4);
    gui.hEig5 = subplot(6, 4,7);
    gui.hEig6 = subplot(6, 4,8);
    gui.hAxClus = subplot(6, 4, 5);
    gui.hAxROI = subplot(6, 4, 6);    
end

%Set callbacks and update display of ROIs on reference
set(gui.hFig, 'WindowButtonDownFcn', @cbMouseclick, ...
              'WindowScrollWheelFcn', @cbScrollwheel, ...
              'KeyPressFcn', @cbKeypress);
gui.hImgMain = imshow(gui.img, 'parent', gui.hAxRef);
title(gui.hAxRef, 'Reference'),
set(gui.hFig, 'userdata', gui),
updateReferenceDisplay(gui.hFig),
    
end

function cbMouseclick(obj, ~, row, col)
%Allows selecting a seed location around which to perform clustering
%and select ROIs

persistent initialClusterNum
if isempty(initialClusterNum)
    initialClusterNum = 6;
end

gui = get(obj, 'userdata');
displayWidth = ceil(gui.covFile.radiusPxCov+2);

%Get current click location

if nargin < 3
    clickCoord = get(gui.hAxRef, 'currentpoint');
    row = clickCoord(1, 2);
    col = clickCoord(1, 1);
    gui.currentPos = [row col];
end

% Ignore clicks that are outside of the image:
[h, w, ~] = size(gui.img);
if row<1 || col<1 || row>h || col>w
    return
end

%If click is valid, define new ROIpt at click location:
if isfield(gui,'hROIpt')
    delete(gui.hROIpt),
end
gui.hROIpt = impoint(gui.hAxRef, [col row]);

% Reset cell / cluster status
% gui.clusterNum = 1;
gui.traceF = [];
gui.indBody = [];
gui.indNeuropil = [];
gui.roiInd = [];

%Get data from cov file and calculate cuts
[covMat, pxNeighbors] = getCovData(gui.hFig, row, col);
gui.pxNeighbors = pxNeighbors;

% Store which pixels have been visited to help the user track their
% progress:
gui.hasBeenViewed(gui.pxNeighbors) = true;
assignin('base', 'hasBeenViewed', gui.hasBeenViewed); % Dirty way provide option to save hasBeenViewed for later use.

%Construct matrices for normCut algorithm using correlation coefficients
W = double(corrcov(covMat, 1)); % Flag = Don't check for correctness of covMat.
D = diag(sum(W));
nEigs = 13;
[eVec,eVal] = eigs((D-W),D,nEigs,-1e-10);
[~,eigOrder] = sort(diag(eVal));
gui.cutVecs = eVec(:,eigOrder(2:nEigs));

%Update cut display axes
mask = zeros(gui.movSize(1), gui.movSize(2));
for nEig = 1:6
    mask(pxNeighbors) = gui.cutVecs(:,nEig);
    hEig = eval(sprintf('gui.hEig%d',nEig));
    imshow(scaleImg(mask),'Parent',hEig),
    axes(hEig),
    xlim([col-displayWidth col+displayWidth]),
    ylim([row-displayWidth row+displayWidth]),
    title(sprintf('Cut #%1.0f',nEig)),
end

% Initial number of cuts is updated depending on previous choices:
initialClusterNum = initialClusterNum + sign(gui.clusterNum-initialClusterNum);
gui.clusterNum = initialClusterNum;

%Display new ROI
set(gui.hFig, 'userdata', gui);
calcROI(gui.hFig);
gui = get(gui.hFig, 'userdata');
updateReferenceDisplay(gui.hFig)

% Load traces:
evt = struct('Key', 'f');
cbKeypress(obj, evt);
end

function cbKeypress(obj, evt)
%Allows interactive selection / manipulation of ROIs. Possibly keypresses:
% 'tab' - Cycles through selection of each cluster in seed region as current ROI.
% 'f' - loads fluorescence trace for currently selected ROI, can be iteratively called to display multiple traces within single seed region
% 'space' - selects current ROI as cell body or neuropil, depending on state, and displays evaluative plots
% '1'-'9' - Selects current ROI or pairing and assigns it to grouping 1-9
% 'backspace' - (delete key) Deletes most recently selected ROI or pairing
% 'm' - Initiates manual ROI selection, via drawing a polygon over the main reference image. This manual ROI is then stored as a new 'cluster'

gui = get(obj, 'userdata');

switch evt.Key    
    case 'm'
        %Turn off figure click callback while drawing ROI
        set(gui.hFig, 'WindowButtonDownFcn', []),
        gui.roiTitle = title(gui.hAxROI, 'Drawing Manual ROI');
        %If a poly somehow wasn't deleted, do it now
        if isfield(gui,'manualPoly') && isvalid(gui.manualPoly)
            delete(gui.manualPoly)
        end
        %Draw polygon on reference image, use mask to add new 'cluster'
        %to allClusters matrix, and select new cluster as current
        gui.manualPoly = impoly(gui.hAxRef);
        set(gui.hFig, 'WindowButtonDownFcn', @cbMouseclick),
        manualMask = createMask(gui.manualPoly);
        newClusterNum = max(gui.allClusters(:))+1;
        gui.allClusters(manualMask) = newClusterNum;
        gui.cluster = newClusterNum;
        %Update cluster display
        displayWidth = ceil(gui.covFile.radiusPxCov+2);
        roiCenter = round(getPosition(gui.hROIpt));
        imshow(label2rgb(gui.allClusters),'Parent',gui.hAxClus),
        axes(gui.hAxClus),
        xlim([roiCenter(1)-displayWidth roiCenter(1)+displayWidth]),
        ylim([roiCenter(2)-displayWidth roiCenter(2)+displayWidth]),
        title(gui.hAxClus, sprintf('Manual ROI over %01.0f cuts',newClusterNum-2)),
        %Delete interactive polygon and update title
        delete(gui.manualPoly),
        gui.roiTitle = title(gui.hAxROI, 'Displaying Manual ROI');
        %Update ROI display
        set(gui.hFig, 'userdata', gui);
        displayROI(gui.hFig),
        gui = get(obj, 'userdata');
        
    case 'backspace'
        if gui.cROI <=1
            return
        end
        % Decrement roi Counter and blank gui label/list
        gui.cROI = gui.cROI - 1;
        gui.roiInfo.roiLabels(gui.roiInfo.roiLabels == gui.cROI) = 0;
        gui.roiInfo.roiList(gui.roiInfo.roiList == gui.cROI) = [];
        
        % Remove indexes from roiInfo and update acquisition object
        gui.roiInfo.roi(gui.cROI) = [];
        gui.roiInfo.grouping(gui.cROI) = 0;
        gui.hAcq.roiInfo.slice(gui.sliceNum) = gui.roiInfo;
        
        %Update Display
        gui.roiTitle = title(gui.hAxROI, 'Last ROI deleted');
        set(gui.hFig, 'userdata', gui);
        updateReferenceDisplay(gui.hFig);
        
    case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}
        roiGroup = str2double(evt.Key);
        gui.roiInfo.grouping(gui.cROI) = roiGroup;
        
        %Check to see if a pairing has just been loaded
        selectStatus = strcmp('This pairing loaded', get(gui.roiTitle,'string'));
        if ~selectStatus || isempty(gui.indBody) || isempty(gui.indNeuropil)
            % Save information for currently selected ROI grouping
            gui.roiInfo.roi(gui.cROI).indBody = find(gui.roiMask);
            newTitle = 'ROI Saved';
        else
            % Save information for recently selected pairing
            gui.roiInfo.roi(gui.cROI).indBody = gui.indBody;
            gui.roiInfo.roi(gui.cROI).indNeuropil = gui.indNeuropil;
            gui.roiInfo.roi(gui.cROI).subCoef = gui.neuropilCoef(2);
            newTitle = 'Cell-Neuropil Pairing Saved';
            
            % Set cluster to be equal to the selected roi, rather than the
            % neuropil, so that we can continue with the next one fluidly:
            gui.cluster = gui.allClusters(gui.indBody(1));
        end
          
        % Update roilabels, list, display. Increment ROI counter
        gui.roiInfo.roiLabels(gui.roiInfo.roi(gui.cROI).indBody) = gui.cROI;
        gui.roiInfo.roiList = sort([gui.roiInfo.roiList; gui.cROI]);
        gui.cROI = gui.cROI + 1;
        set(gui.hFig, 'userdata', gui);
        updateReferenceDisplay(gui.hFig);
        gui.roiTitle = title(gui.hAxROI, sprintf('%s: #%03.0f',newTitle,gui.cROI-1));
        
        % Save gui data to acquisition object handle
        gui.hAcq.roiInfo.slice(gui.sliceNum) = gui.roiInfo;
                
    case 'f'
        gui.roiTitle = title(gui.hAxROI, 'Loading Trace for Current ROI');
        drawnow,
        
        %Add new ROI fluorescence trace to end of traceF matrix
        mov = gui.movMap.Data.mov;
        gui.traceF(end+1,:) = mean(mov(:, gui.hAcq.mat2binInd(find(gui.roiMask))), 2)'; %#ok<FNDSB>

        %Get matrix of fluorescence traces for all clusters:
        gui.traceF = [];
        for i = 1:gui.clusterNum+1
            gui.traceF(end+1,:) = mean(mov(:, gui.hAcq.mat2binInd(find(gui.allClusters==i))), 2)'; %#ok<FNDSB>
            gui.traceF(end, gui.excludeFrames) = nan;
        end
        clear mov;
        
        %Normalize, smooth, and plot all traces
        dF = bsxfun(@rdivide, gui.traceF, nanmedian(gui.traceF,2));
        for i=1:size(dF,1)
            dF(i,:) = conv(dF(i,:)-1,gausswin(gui.smoothWindow)/sum(gausswin(gui.smoothWindow)),'same');
        end
        dF = bsxfun(@plus, dF, 1*(size(dF, 1):-1:1)'); % Offset traces in y.
        figure(786),
        clf
        whitebg(786, [0.2 0.2 0.2]);
        
        % Coloring: use same hues as in the image showing the cuts, but
        % scale saturation according to the magnitude of the fluorescence
        % signal:
        clut = jet(gui.clusterNum+1);
        clut = cat(1, clut, jet(gui.clusterNum+1));
        set(gcf, 'defaultAxesColorOrder', clut);
        hold on
        plot(dF', 'linewidth', 1)
        gui.roiTitle = title(gui.hAxROI, 'This trace loaded');
        
        % reset neuroPil index, to prevent accidental saving of previous pairing
        gui.indNeuropil = [];
        figure(gui.hFig)
    case 'space'
        %Determine if selection is new cell body or paired neuropil
        neuropilSelection = strcmp('Select neuropil pairing', get(gui.roiTitle,'string'));
        if ~neuropilSelection
            %Get indices of current ROI as cell body + update title state
            gui.indBody = find(gui.roiMask);
            gui.roiTitle = title(gui.hAxROI, 'Select neuropil pairing');
            
            % Switch to largest cut, because that's probably the neuropil:
            [~, clustSizeInd] = sort(histcounts(gui.allClusters(:)), 'descend');
            gui.cluster = clustSizeInd(2)-1; % Number 1 is background (zeros, no cluster).

            %Update ROI display
            set(gui.hFig, 'userdata', gui);
            displayROI(gui.hFig),
            gui = get(obj, 'userdata');
            
        elseif neuropilSelection
            gui.roiTitle = title(gui.hAxROI, 'Loading Trace for cell-neuropil pairing');
            drawnow,
            
            %Get indices of current ROI as paired neuropil
            gui.indNeuropil = find(gui.roiMask);
            
            %Load cell body and neuropil fluorescence
            mov = gui.movMap.Data.mov;
            cellBody = mean(mov(:, gui.hAcq.mat2binInd(gui.indBody)), 2)';
            cellNeuropil = mean(mov(:, gui.hAcq.mat2binInd(gui.indNeuropil)), 2)';
            clear mov
            
            % Interpolate across excluded frames:
            cellBody(gui.excludeFrames) = [];
            cellNeuropil(gui.excludeFrames) = [];
            
            % Display un-deBleached coefficient to check it is similar to
            % de-bleached coeff:
            if true
                cellBodySmooth = conv(cellBody,gausswin(gui.smoothWindow)/sum(gausswin(gui.smoothWindow)),'valid');
                cellNeuropilSmooth = conv(cellNeuropil,gausswin(gui.smoothWindow)/sum(gausswin(gui.smoothWindow)),'valid');

                %Extract subtractive coefficient btw cell + neuropil and plot
                
                isSelmaansMethod = false;
                
                if isSelmaansMethod
                    cellInd = cellBodySmooth<median(cellBodySmooth)+mad(cellBodySmooth)*2;
                    neuropilCoefWithBleaching = robustfit(cellNeuropilSmooth(cellInd)-median(cellNeuropilSmooth),cellBodySmooth(cellInd)-median(cellBodySmooth),...
                        'bisquare',4);
                else
                    neuropilCoefWithBleaching = robustfit(cellNeuropilSmooth, cellBodySmooth, 'talwar', 1);
                end
            end
            
            % Remove bleaching:
            figure(784)
            clf
            hold on
            plot(cellNeuropil+100)
            plot(cellBody+100)
            
            cellF = prctile(cellBody,10);
            cellBody = deBleach(cellBody, 'linear');
            cellNeuropil = deBleach(cellNeuropil, 'linear');
            
            %Smooth fluorescence traces
            cellBody = conv(cellBody,gausswin(gui.smoothWindow)/sum(gausswin(gui.smoothWindow)),'valid');
            cellNeuropil = conv(cellNeuropil,gausswin(gui.smoothWindow)/sum(gausswin(gui.smoothWindow)),'valid');
            
            %Extract subtractive coefficient btw cell + neuropil and plot
            
            figure(783)
            if isSelmaansMethod
                cellInd = cellBody<median(cellBody)+mad(cellBody)*2;
                gui.neuropilCoef = robustfit(cellNeuropil(cellInd)-median(cellNeuropil),cellBody(cellInd)-median(cellBody),...
                    'bisquare',4);            plot(cellNeuropil-median(cellNeuropil), cellBody-median(cellBody),'.','markersize',3)
                xRange = round(min(cellNeuropil-median(cellNeuropil))):round(max(cellNeuropil-median(cellNeuropil)));
                hold on
                plot(xRange,xRange*gui.neuropilCoef(2) + gui.neuropilCoef(1),'r')
                hold off
            else
                gui.neuropilCoef = robustfit(cellNeuropil, cellBody, 'talwar', 1);            
                plot(cellNeuropil(1:10:end), cellBody(1:10:end), '.', 'markersize', 3)
                xRange = round(min(cellNeuropil)):round(max(cellNeuropil));
                hold on
                plot(xRange,xRange*gui.neuropilCoef(2) + gui.neuropilCoef(1),'r')
                hold off
                set(gca, 'dataaspect', [1 1 1]);
            end
            

            title(sprintf('Fitted subtractive coefficient is: %0.3f (%0.3f w/o debleach)',gui.neuropilCoef(2), neuropilCoefWithBleaching(2))),
            
            %Calculate corrected dF and plot
            dF = cellBody-cellNeuropil*gui.neuropilCoef(2);
            dF = dF/cellF;
            dF = dF - median(dF);
            figure(784),
            plot(cellNeuropil),
            hold on,
            plot(cellBody),
            hold off,
            legend('NP raw', 'Body raw', 'NP debleached', 'Body debleached');
            
            figure(785),
            plot(dF,'linewidth',1.5)
            gui.roiTitle = title(gui.hAxROI, 'This pairing loaded');
            figure(gui.hFig);
            
        end
    case 'tab'
        %Increase currently selected cluster by 1
        clusters = max(gui.allClusters(:));
        gui.cluster = mod(gui.cluster+1,clusters+1);
        
        %If index exceeds # of clusters, loop back to first cluster
        if gui.cluster == 0
            gui.cluster = 1;
        end
        
        %Update ROI display
        set(gui.hFig, 'userdata', gui);
        displayROI(gui.hFig),
        gui = get(obj, 'userdata');
        
    case 'downarrow'
        % Downarrow is like a click below the last selected point, to look
        % at a region that perfectly exploits the column-wise loading of
        % movie traces:
        row = gui.currentPos(1);
        col = gui.currentPos(2);
        
        row = row + round(gui.covFile.radiusPxCov*4/3);
        
        if row>gui.movSize(1)
            % If we're at the bottom of the column, jump to the next one:
            row = 1;
            col = col + round(gui.covFile.radiusPxCov*4/3);
        end
        
        gui.currentPos = [row col];
        set(gui.hFig, 'userdata', gui);
        cbMouseclick(obj, [], row, col);
        gui = get(gui.hFig, 'userdata');
        
    case 'uparrow'
        % Uparrow is like a click above the last selected point, to look
        % at a region that perfectly exploits the column-wise loading of
        % movie traces:
        row = gui.currentPos(1);
        col = gui.currentPos(2);
        
        row = row - round(gui.covFile.radiusPxCov*4/3);
        
        if row<1
            % If we're at the top of the column, jump to the previous one:
            row = gui.movSize(1);
            col = col - round(gui.covFile.radiusPxCov*4/3);
        end
        
        gui.currentPos = [row col];
        set(gui.hFig, 'userdata', gui);
        cbMouseclick(obj, [], row, col);
        gui = get(gui.hFig, 'userdata');
end

set(gui.hFig, 'userdata', gui);
 end

function cbScrollwheel(obj, evt)
%Allows interactive adjustment of the number of clusters / cuts to perform

%Determine scrolling direction and update cluster count accordingly
gui = get(obj, 'userdata');
nEigs = size(gui.cutVecs, 2);
switch sign(evt.VerticalScrollCount)
    case -1 % Scrolling up
        if gui.clusterNum < nEigs
            gui.clusterNum = gui.clusterNum + 1;
        else
            return
        end
    case 1 % Scrolling down
        if gui.clusterNum > 1
            gui.clusterNum = gui.clusterNum - 1;
        else
            return
        end
end
%Recalculate clusters with new cluster count
set(gui.hFig, 'userdata', gui);
calcROI(gui.hFig);
end

function updateReferenceDisplay(hFig)
%Helper function that updates the reference image with current ROI labels

gui = get(hFig, 'userdata');
% Add colored ROI labels:
img = gui.img;
img(img>prctile(img(:), 98)) = prctile(img(:), 95);
img(:,:,2) = img(:,:,2) ./ (gui.hasBeenViewed*0.2+1);

if ~isempty(gui.roiInfo.roiList)
    %get number of groups
    uniqueGroups = unique(gui.roiInfo.grouping);
    nGroups = length(uniqueGroups);
    
    colorOptions = gui.roiColors(mod(1:nGroups, 30)+1, :);
    clut = zeros(max(gui.roiInfo.roiList),3);
    for groupInd = 1:nGroups
        clut(gui.roiInfo.grouping == groupInd, :) = repmat(colorOptions(groupInd, :),...
            sum(gui.roiInfo.grouping == groupInd), 1);
    end
    roiCdata = double(myLabel2rgb(gui.roiInfo.roiLabels, clut))/255;
    cdata = scaleImg(img.*roiCdata);
    
%     %turn hold on
%     hold on;
%     
%     %get number of groups
%     uniqueGroups = unique(gui.roiInfo.grouping);
%     nGroups = length(uniqueGroups);
%     
%     %loop through each group
%     for groupInd = 1:nGroups
%         
%         %find rois which match group
%         matchROIs = find(gui.roiInfo.grouping == groupInd);
%         
%         %create binary matrix of pixels which match group
%         groupMatch = ismember(gui.roiInfo.roiLabels, matchROIs);
%         
%         %convert to linear array
%         groupMatch = find(groupMatch(:));
%         
%         %convert to row and column indices
%         [rowInd, colInd] = ind2sub(size(gui.roiInfo.roiLabels),groupMatch);
%         
%         %create patch object
%         patch(rowInd,colInd,[1 0 0]);       
%         
%     end
    
else
    cdata = scaleImg(img);
end
%Replot to main reference image
set(gui.hImgMain, 'cdata', cdata);

set(gui.hFig, 'userdata', gui);
end

function calcROI(hFig)
%Helper function that performs clustering using n simultaneous normcuts and
%updates cluster/ROI display accordingly

gui = get(hFig, 'userdata');
clusterNum = gui.clusterNum;
roiCenter = round(getPosition(gui.hROIpt));
pxNeighbors = gui.pxNeighbors;
displayWidth = ceil(gui.covFile.radiusPxCov+2);

%Perform kmeans clustering on n smallest cuts
clusterIndex = kmeans(gui.cutVecs(:,1:clusterNum),clusterNum+1,'Replicates',10);

%Display current clustering results
mask = zeros(512);
mask(pxNeighbors) = clusterIndex;
gui.allClusters = mask;
imshow(label2rgb(mask),'Parent',gui.hAxClus),
axes(gui.hAxClus),
xlim([roiCenter(1)-displayWidth roiCenter(1)+displayWidth]),
ylim([roiCenter(2)-displayWidth roiCenter(2)+displayWidth]),
title(gui.hAxClus, sprintf('Clustering with %01.0f cuts',clusterNum)),

%Autoselect cluster at click position and display
gui.cluster = gui.allClusters(roiCenter(2),roiCenter(1));
gui.roiTitle = title(gui.hAxROI, 'ROI Selection');
set(gui.hFig, 'userdata', gui);
displayROI(hFig),
end

function displayROI(hFig)
%Helper function which updates display of currently selected ROI in overlay
%panel

gui = get(hFig, 'userdata');
displayWidth = ceil(gui.covFile.radiusPxCov+2);
roiCenter = round(getPosition(gui.hROIpt));

%Check current status, reflected in title of ROI overlay axes. If trace has
%recently been loaded, reset title to ROI selection, or if currently
%searching for neuropil, do not enforce ROI continuity constraint
enforceContinuity = 1;
% enforceContinuity = 0; % Continuity is not always desired when selecting small axon/dendrite rois.

currentTitle = get(gui.roiTitle,'string');
if strcmp(currentTitle,'This trace loaded') || strcmp(currentTitle,'This pairing loaded')
    currentTitle = 'ROI Selection';
elseif strcmp(currentTitle,'Select neuropil pairing')
    enforceContinuity = 0;
end

%Get mask corresponding to currently selected cluster, and optionally
%enforce that only the largest connected component of cluster is selected
gui.roiMask = gui.allClusters == gui.cluster;
if enforceContinuity == 1
    CC = bwconncomp(gui.roiMask);
    numPix = cellfun(@numel,CC.PixelIdxList);
    [~,bigROI] = max(numPix);
    gui.roiMask(~ismember(1:512^2,CC.PixelIdxList{bigROI})) = 0;
end

%(not so) gracefully handle ROIs near image border 
%TODO: improve this!
iOffS = (1+displayWidth-roiCenter(2)) * ((roiCenter(2)-displayWidth)<1);
iOffE = (roiCenter(2)+displayWidth-gui.movSize(1)) * ((roiCenter(2)+displayWidth)>gui.movSize(1));
jOffS = (1+displayWidth-roiCenter(1)) * ((roiCenter(1)-displayWidth)<1);
jOffE = (roiCenter(1)+displayWidth-gui.movSize(2)) * ((roiCenter(1)+displayWidth)>gui.movSize(2));

%Grab appropriate region around seed, enhance contrast, and overlay roi mask
roiImg = gui.img(roiCenter(2)-displayWidth+iOffS:roiCenter(2)+displayWidth-iOffE,...
    roiCenter(1)-displayWidth+jOffS:roiCenter(1)+displayWidth-jOffE,1);
roiImg = repmat(scaleImg(roiImg)/.9 +.1,[1 1 3]);
img = gui.img;
img(roiCenter(2)-displayWidth+iOffS:roiCenter(2)+displayWidth-iOffE,...
    roiCenter(1)-displayWidth+jOffS:roiCenter(1)+displayWidth-jOffE,1:3) = roiImg;
roiOverlay(:,:,1) = gui.roiMask;
roiOverlay(:,:,2) = 1;
roiOverlay(:,:,3) = ~gui.roiMask;
imshow(img .* roiOverlay,'Parent',gui.hAxROI),
axes(gui.hAxROI),
xlim([roiCenter(1)-displayWidth roiCenter(1)+displayWidth]),
ylim([roiCenter(2)-displayWidth roiCenter(2)+displayWidth]),
gui.roiTitle = title(gui.hAxROI, currentTitle);
set(gui.hFig, 'userdata', gui);
end

function RGB = myLabel2rgb(label, cmap)
% Like MATLAB label2RGB, but skipping some checks to be faster:
cmap = [[1 1 1]; cmap]; % Add zero color
RGB = ind2rgb8(double(label)+1, cmap);
end

function img = scaleImg(img)
img = img-min(img(:));
img = img./max(img(:));
end

function [covMat, pxNeighbors] = getCovData(hFig, row, col)
% [covMat, pixNeighbors] = getCovData(hFig) extracts the covariance data
% for one "seed" pixel from the covFile. This function deals with the
% different covFile formats.

gui = get(hFig, 'userdata');
[h, w, ~] = size(gui.img);

% Which file format is it?
% covFileVars = whos(gui.covFile);

if isa(gui.covFile, 'matlab.io.MatFile')
    % Classic seedCov as developed by Selmaan:
    format = 'seedCov';
else
    % PixCov as developed by Matthias:
    format = 'pixCovMjlm';
end

switch format
    case 'seedCov'
        % Find seed closest to click:
        row = round(row/gui.covFile.seedBin);
        col = round(col/gui.covFile.seedBin);
        seedNum = (col-1)*round(h/gui.covFile.seedBin) + row;
        
        % Retrieve data:
        nNeighbors = gui.covFile.nNeighbors(1,seedNum);
        pxNeighbors = gui.covFile.pxNeighbors(1:nNeighbors,seedNum);
        covMat = gui.covFile.seedCov(1:nNeighbors,1:nNeighbors,seedNum);
        %dFMat = double(covMat./(gui.mRef(pxNeighbors)*gui.mRef(pxNeighbors)'));
        
    case 'pixCovMjlm'
        row = round(row);
        col = round(col);
        nh = gui.roiInfo.covFile.nh;
        [covMat, pxNeighbors] = mmCovMat(gui.covFile.map.Data.pixCov, h, w, nh, row, col);
end

set(hFig, 'userdata', gui);
end

function A = mrow(A)
A = A(:)';
end

function A = mcol(A)
A = A(:);
end

function A_interp = interpNans(A, method)

if ~exist('method', 'var')
    method = 'linear';
end

[r, c] = size(A);

A = A(:);

isnanA = isnan(A);

% Interp1 cannot replace nans at the start and end of A, so we use
% this dirty fix, which also ensures that A remains strictly monotonically
% increasing if it was beforehand (this is important if A is to be used
% with interp later):
firstNoNan = find(~isnanA, 1, 'first');
lastNoNan = find(~isnanA, 1, 'last');
if isnanA(1)
    A(1) = A(firstNoNan)-1;
end
if isnanA(end)
    A(end) = A(lastNoNan)+1;
end

isnanA = isnan(A); % Recalculate after replacing edge nans.
indAll = 1:numel(A);
indNoNan = indAll(~isnanA);
A_interp = interp1(indNoNan, A(~isnanA), indAll, method);

if r>c
    A_interp = A_interp';
end
end