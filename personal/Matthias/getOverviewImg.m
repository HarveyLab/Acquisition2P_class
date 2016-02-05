function img = getOverviewImg(acq)
% Merges the anatomical and activity images into a nice overview image for
% selectRois

%% Get mean img:
mode = 'standard';

switch mode
    case 'standard'    
        meanImg = acq.meanRef;
        meanImg(meanImg<0) = 0;
        meanImg(isnan(meanImg)) = 0;
        meanImg = sqrt(meanImg);
        meanImg = adapthisteq(meanImg/max(meanImg(:)));
        meanImg = repmat(meanImg, 1, 1, 3);
        
    case 'high contrast'
        meanImg = mat2gray(max(acq.meanRef([],[],[],0), [], 3), [0 500]);
        meanImg = adapthisteq(meanImg, 'clipLimit', 0.005, 'numTiles', [20 20]);
end

%% Get activity img:
actImg = imadjust(mat2gray(acq.roiInfo.slice(1).covFile.activityImg));


img(:,:,1) = 0.7*meanImg(:,:,2)+0.3*actImg;