function img = getOverviewImg_lnd(acq,sliceNum)
% Merges the anatomical and activity images into a nice overview image for
% selectRois
img = acq.meanRef([],sliceNum);
img(img<0) = 0;
img(isnan(img)) = 0;
img = sqrt(img);
img = adapthisteq(img/max(img(:)));
img = repmat(img, 1, 1, 3);
actImg = imadjust(mat2gray(acq.roiInfo.slice(sliceNum).covFile.activityImg));
img(:,:,1) = 0.7*img(:,:,2)+0.3*actImg;