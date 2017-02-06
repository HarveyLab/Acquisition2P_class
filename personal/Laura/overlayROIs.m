close all
sliceNum = 2;

roiInds = cat(1,acq1.roiInfo.slice(sliceNum).roi(:).indBody);%,acq2.roiInfo.slice(sliceNum).roi(:).indBody);
roiIm = zeros(512,512);
roiIm(roiInds) = 1;

anIm = getOverviewImg_lnd(acq,sliceNum);
anIm(:,:,3) = .7*squeeze(anIm(:,:,1))+.3*roiIm;
img = anIm(:,:,3);
acq.selectROIs(anIm,sliceNum)