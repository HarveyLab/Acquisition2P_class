function img = getOverviewImg(acq, altImg)
% Merges the anatomical and activity images into a nice overview image for
% selectRois

if nargin<2
    altImg = [];
end

%% Get mean img:
mode = 'standard';

switch mode
    case 'standard'    
        meanImg = acq.meanRef;
        meanImg(meanImg<0) = 0;
        meanImg(isnan(meanImg)) = 0;
        meanImg = sqrt(meanImg);
        meanImg = adapthisteq(meanImg/max(meanImg(:)));
        
    case 'high contrast'
        meanImg = mat2gray(max(acq.meanRef([],[],[],0), [], 3), [0 500]);
        meanImg = adapthisteq(meanImg, 'clipLimit', 0.001, 'numTiles', [30 30]);
%         meanImg = meanImg*0.7;
end

meanImg = repmat(meanImg, 1, 1, 3);
%% Get activity img:
if isempty(altImg)
    actImg = imadjust(mat2gray(acq.roiInfo.slice(1).covFile.activityImg));
else
    actImg = imadjust(mat2gray(altImg))*5;
end

img = meanImg;
img(:,:,1) = 0.7*meanImg(:,:,2)+0.3*actImg;