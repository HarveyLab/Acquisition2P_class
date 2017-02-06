%% Make avg movie

%tV = vecTrials(stimExpt);
movNeur = unique(tV.nTarg);
targOn = [];
for iNeur = 1:length(movNeur)
    nNeur = movNeur(iNeur);
    repF = find(tV.nTarg == nNeur);
    for f = 1:length(repF)
        targOn(iNeur,f) = tV.stimFrames{repF(f)}(1);
    end
end
frameWin = -15:84;
%frameWin = -6:43;
mMov = nan(512,512,length(frameWin)*size(targOn,1),'single');
for t = 1:size(targOn,1)
    keyFrames = targOn(t,:);t,
    fInd = (t-1)*length(frameWin)+1 : t*length(frameWin);
    mMov(:,:,fInd) = avgMov(expt1,keyFrames,frameWin);
end

%% Register Pathways
nPoints = 4;

stim = imNorm(stimExpt.StimROIs.imData(:,:,1));
res = imNorm(meanRef(expt1));
stim2 = imresize(stim,1/1.4);

sFig = figure;
imshow(stim2),
rFig = figure;
imshow(res),
for nPoint=1:nPoints
    figure(sFig),
    mvPt(nPoint,:) = getPosition(impoint);
    figure(rFig),
    fxPt(nPoint,:) = getPosition(impoint);
end
close(sFig),
close(rFig),

s2r = fitgeotrans(mvPt,fxPt,'affine');
sWarp = imwarp(stim2,s2r,'OutputView',imref2d(size(res)));
figure,imshowpair(res,sWarp),
%% Extract ROIs and responses
fStimPre = 1:15;
fStimPost = 22:36;
hEl = dispStimROIs(stimExpt.StimROIs);

mAll = zeros(size(mMov,1)*size(mMov,2),1);
for nROI = 1:length(hEl)
    m = createMask(hEl(nROI));
    m = imwarp(imresize(m,1/1.4),s2r,'OutputView',imref2d(size(res)));
    m = reshape(m,1,[]);
    mAll = mAll + m';
    trace(nROI,:) = m*reshape(mMov,[],size(mMov,3));
end
dF = bsxfun(@rdivide,trace,median(trace,2)) - 1;

mAll = reshape(mAll,size(mMov,1),size(mMov,2));
resROI(:,:,1) = res;
resROI(:,:,2) = res.*(1-mAll);
resROI(:,:,3) = res.*(mAll);
figure,imshow(resROI),

for nTarg = 1:length(hEl)
        tMod = (nTarg-1)*length(frameWin);
        dFresp = mean(dF(:,fStimPost+tMod),2) - ...
            mean(dF(:,fStimPre+tMod),2);
        respMat(nTarg,:) = dFresp;
        dFtarg(nTarg,:) = dF(nTarg,(1:length(frameWin))+tMod);
end

figure,plot(frameWin,dFtarg'),
respMat(respMat<0) = 0;
figure,imagesc(respMat),
%figure,plot(diag(respMat)'./sum(respMat),'.')