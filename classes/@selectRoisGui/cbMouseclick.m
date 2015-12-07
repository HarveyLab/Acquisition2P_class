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

invC = 1-corrMat;
pilC = median(invC(~isnan(invC(:))));
corrMat = exp(-1/(1*pilC^2) * invC.^2);

% Deal with nan rows/cols:
% (Set weights between nan pixels high and between them and other pixels
% low, so that they are thrown into the same cut.)
% nanRows = all(isnan(W), 2);
% nanCols = all(isnan(W), 1);
% W(nanRows, :) = 0;
% W(:, nanCols) = 0;
% W(nanRows, nanCols) = max(W(:));

%% Initialize Factors
fprintf('Initializing Factors \n'),
nFactors = 30;
w = initFactors(corrMat,nFactors);
nFactors = size(w,2);
w = [w,rand(size(w,1),6)];

%% Refine Factors
fprintf('Loading Movie \n'),
mov = sel.movMap.Data.mov;
nh = sel.roiInfo.covFile.nh;
nhInd = 1:nh^2;
movInd = sel.nh2movInd(nhInd);
oMov = mov(:, sel.acq.mat2binInd(movInd))';
clear mov
nFrames = size(oMov,2);
oMov = squeeze(sum(reshape(oMov(:,1:end-mod(nFrames,10)),nh^2,10,[]),2));
%oMov = sqrt(oMov);

fprintf('Refining Factors \n'),
t = pinv(w)*oMov;
its = 0;
converged = 0;
convThresh = 1e-4;
wBaseline = 1;
while ~converged
    its = its+1;
    w0 = w;
    [w,t] = updateSimNMF(oMov,t,nFactors,wBaseline);
    converged = mean(abs(w0(:)-w(:)))<convThresh;mean(w0(:)-w(:));
end
fprintf('Refinement took %d iterations \n',its),

figure(4693),clf,
for nFactor = 1:size(w,2)
    subplot(4,4,nFactor),
    imshow(imNorm(reshape(w(:,nFactor),nh,nh))),
end

its = 0;
converged = 0;
convThresh = 1e-5;
wBaseline = 80;
while ~converged
    its = its+1;
    w0 = w;
    [w,t] = updateSimNMF(oMov,t,nFactors,wBaseline);
    converged = mean(abs(w0(:)-w(:)))<convThresh;mean(w0(:)-w(:));
end
fprintf('Sparsification took %d iterations \n',its),


% [~,sortOrder] = sort(sqrt(sum(t(1:nFactors-2,:).^2,2)),1,'descend');
% [~,sortOrder] = sort(median(t(1:nFactors-2,:),2),1,'descend');
% sortOrder = [sortOrder;nFactors-1;nFactors];
% [~,sortOrder] = sort(skewness(w(:,1:nFactors-2)),2,'ascend');
% sortOrder = [sortOrder,nFactors-1,nFactors];
% w=w(:,sortOrder);
% t=t(sortOrder,:);    

figure(4694),clf,
for nFactor = 1:size(w,2)
    subplot(4,4,nFactor),
    imshow(imNorm(reshape(w(:,nFactor),nh,nh))),
end

%tF = pinv(w)*oMov.^2;
tF = pinv(w)*oMov;
% figure(9874),plot(tF(nFactors-1,:))
% figure(9875),plot(tF(nFactors,:))
assignin('base','guiT',tF),

%% Display

sel.disp.cutVecs = w;
sel.disp.cutVals = sqrt(sum(t.^2,2));

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