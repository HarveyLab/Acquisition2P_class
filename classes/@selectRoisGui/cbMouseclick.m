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

%If click is valid, define new ROIpt at click location:
if isfield(sel.h.ui,'roiPoint')
    delete(sel.h.ui.roiPoint)
end
sel.h.ui.roiPoint = impoint(sel.h.ax.overview, [col row]);

% Reset cell / cluster status:
sel.disp.indBody = [];
sel.disp.indNeuropil = [];
sel.disp.roiInd = [];

%Get data from cov file and calculate cuts
[covMat, pxNeighbors] = sel.getCovData;

% Store which pixels have been visited to help the user track their
% progress:
sel.roiInfo.hasBeenViewed(pxNeighbors) = 1;

%Construct matrices for normCut algorithm using correlation coefficients
W = double(corrcov(covMat, 1)); % Flag = Don't check for correctness of covMat.
D = diag(sum(W));
nEigs = 13;
[eVec,eVal] = eigs((D-W),D,nEigs,-1e-10);
[~,eigOrder] = sort(diag(eVal));
sel.disp.cutVecs = eVec(:, eigOrder(2:nEigs));

%Update cut display axes
nh = sel.roiInfo.covFile.nh;
existingRoiMask = double(~reshape(sel.disp.roiLabels(pxNeighbors), nh, nh));
existingRoiMask(existingRoiMask==0) = 0.9;
for ii = 1:numel(sel.h.img.eig);
    eVecImg = reshape(sel.disp.cutVecs(:,ii), nh, nh);
    eVecImg = mat2gray(eVecImg);
    eVecImg = repmat(eVecImg, 1, 1, 3);
    eVecImg(:,:,1) = eVecImg(:,:,1) .* existingRoiMask;
    eVecImg(:,:,3) = eVecImg(:,:,3) .* existingRoiMask;
    set(sel.h.img.eig(ii), 'cdata', eVecImg);
    title(sel.h.ax.eig(ii), sprintf('Cut %d', ii))
end

%Display new ROI
sel.calcRoi;
sel.updateOverviewDisplay(false);

% Load traces:
if strcmp(sel.h.timers.loadTraces.Running, 'off')
    start(sel.h.timers.loadTraces);
end
end