function cbMouseclick(sel, objClick, ~, row, col)
%Allows selecting a seed location around which to perform clustering
%and select ROIs

persistent initialClusterNum

% Ignore if right click
if ~strcmp(get(objClick, 'SelectionType'), 'normal') %if right click
    return
end

% Get current click location
if nargin < 4
    clickCoord = get(sel.h.ax.overview, 'currentpoint');
    row = clickCoord(1, 2);
    col = clickCoord(1, 1);
    
    % Ignore out-of-bounds clicks:
    if row < sel.h.ax.overview.YLim(1) || row > sel.h.ax.overview.YLim(2) ||...
            col < sel.h.ax.overview.XLim(1) || col > sel.h.ax.overview.XLim(2)
        return
    end
    sel.disp.currentPos = [row col];
end

% Initial number of cuts is updated depending on previous choices:
if isempty(initialClusterNum)
    initialClusterNum = sel.disp.clusterNum;
else
    initialClusterNum = initialClusterNum + sign(sel.disp.clusterNum-initialClusterNum);
    sel.disp.clusterNum = initialClusterNum;
end
sel.disp.clusterMod = 0;
sel.disp.cutMod_nTopToExclude = 0;

%If click is valid, define new ROIpt at click location:
if isfield(sel.h.ui,'roiPoint')
    delete(sel.h.ui.roiPoint)
end
sel.h.ui.roiPoint = impoint(sel.h.ax.overview, [col row]);
setColor(sel.h.ui.roiPoint, 'w');

% Reset cell / cluster status:
sel.disp.indBody = [];
sel.disp.indNeuropil = [];
sel.disp.roiInd = [];

% Clear overlay plot
cla(sel.h.ax.traceOverlay),

%Get data from cov file and calculate cuts
isCustomNhEnabled = isfield(sel.disp, 'nhTemp');

if isCustomNhEnabled && ~isnan(sel.disp.nhTemp.custom) % This allows user to change NH size on the fly
    % Get movie data:
    nh = sel.disp.nhTemp.custom;
    sel.roiInfo.covFile.nh = nh; % To fool other code that reads nh from roiInfo.
    nhInd = 1:nh^2;
    pxNeighbors = sel.nh2movInd(nhInd, sel.disp.currentPos, nh);
    movHere = double(sel.movMap.Data.mov(:, sel.acq.mat2binInd(pxNeighbors))');
    covMat = corr(movHere');
else
    if isCustomNhEnabled
        % If we are using the custom nh function, we have to clean up any
        % changes that we may have made to make the temporary nh work
        % (above):
        sel.roiInfo.covFile.nh = sel.disp.nhTemp.original; % In case it has been changed above.
    end
    [covMat, pxNeighbors] = sel.getCovData;
    nh = sel.roiInfo.covFile.nh;
end

if isCustomNhEnabled
    % Draw images at correct sizes:
    sel.h.img.cluster = imshow(zeros(sel.roiInfo.covFile.nh), 'Parent', sel.h.ax.cluster);
    sel.h.img.roi = imshow(zeros(sel.roiInfo.covFile.nh), 'Parent', sel.h.ax.roi);
end

% Store which pixels have been visited to help the user track their
% progress:
sel.roiInfo.hasBeenViewed(pxNeighbors) = 1;

%Construct matrices for normCut algorithm using correlation coefficients
corrMat = double(corrcov(covMat, 0)); % Flag = Don't check for correctness of covMat.

% Apply modification to the correlation matrix to maximize difference
% between neuropil and cells:
invC = 1-corrMat;
pilC = median(invC(~isnan(invC(:))));
corrMat = exp(-1/(1*pilC^2) * invC.^2);

% Add weight to neighboring pixels (first off-diagonal) to penalize cuts
% with long borders:
m = size(corrMat, 1);
% offDiags = diag2full(ones(m, 8), [-nh-1 -nh -nh+1 -1 1 nh-1 nh nh+1], m, m); % 8-connected
offDiags = diag2full(ones(m, 4), [-nh -1 1 nh], m, m); % 4-connected
nhWeight = 1;
W = corrMat + nhWeight*offDiags;

% Deal with nan rows/cols:
% (Set weights between nan pixels high and between them and other pixels
% low, so that they are thrown into the same cut.)
nanRows = all(isnan(W), 2);
nanCols = all(isnan(W), 1);
W(nanRows, :) = 0;
W(:, nanCols) = 0;
W(nanRows, nanCols) = max(W(:));

D = diag(sum(W));
nEigs = 21;
[eVec,eVal] = eigs((D-W),D,nEigs,-1e-10);
[~,eigOrder] = sort(diag(eVal));
eigOrder = eigOrder(2:end);
sel.disp.cutVecs = zeros(size(eVec, 1), nEigs);
for nEig = 1:nEigs-1
    nOrd = eigOrder(nEig);
    sel.disp.cutVals(nEig) = eVal(nOrd,nOrd);
    sel.disp.cutVecs(:,nEig) = eVec(:,nOrd)./(sel.disp.cutVals(nEig)+1e-2);
end

% Calculate #cuts and #clusters
sel.calcClusterProps;

%Update cut display axes
existingRoiMask = double(~reshape(sel.disp.roiLabels(pxNeighbors), nh, nh));
existingRoiMask(existingRoiMask==0) = 0.9;
for ii = 1:numel(sel.h.img.eig);
    eVecImg = reshape(sel.disp.cutVecs(:,ii), nh, nh);
    eVecImg = mat2gray(real(eVecImg)); % Real prevents error in cases when eVecs are imaginary.
    eVecImg = repmat(eVecImg, 1, 1, 3);
    eVecImg(:,:,1) = eVecImg(:,:,1) .* existingRoiMask;
    eVecImg(:,:,3) = eVecImg(:,:,3) .* existingRoiMask;
    set(sel.h.img.eig(ii), 'cdata', eVecImg);
    title(sel.h.ax.eig(ii), sprintf('Cut %d: %0.3f', ii, sel.disp.cutVals(ii)))
end

%Display new ROI
sel.calcRoi;
sel.updateOverviewDisplay(false);

% Load traces if requested
if get(sel.h.ui.autoLoadTraces,'Value') == 1 && strcmp(sel.h.timers.loadTraces.Running, 'off')
    start(sel.h.timers.loadTraces);
else
    stop(sel.h.timers.loadTraces);
end

end