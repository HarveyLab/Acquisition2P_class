function [stimMov, dFmov] = getStimEvokedMovie(stimExpt, nROI, nTarg, winSize)

if nargin < 4
    winSize = 30;
end

if nargin < 3
    nTarg = nROI;
end

tV = stimExpt.tV;

mov = getRoiMovie(stimExpt.acq, nROI, winSize);
stimTimes = cellfun(@min,tV.stimFrames(tV.nTarg==nTarg));

stimFrames = [];
for i=1:length(stimTimes)
    stimFrames(i,:) = stimTimes(i)-30:stimTimes(i)+90;
end
stimFrames(stimFrames<1)=1;
stimFrames(stimFrames>size(mov,3))=size(mov,3);
stimMov = mov(:,:,stimFrames(:));
stimMov = squeeze(mean(reshape(stimMov,...
    [size(mov,1) size(mov,2) size(stimFrames,1) size(stimFrames,2)]),3));
% implay((stimMov-min(stimMov(:)))/max(stimMov(:)))
dFmov = (bsxfun(@rdivide,stimMov,mean(mov,3))-1);
% implay(dFmov/max(dFmov(:)))