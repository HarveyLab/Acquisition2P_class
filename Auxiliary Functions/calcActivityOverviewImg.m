function actImg = calcActivityOverviewImg(pixCov, diags, h, w)
% actImg = calcActivityOverviewImg(pixCov, diags, h, w) calculates an image
% displaying the variance of the correlation of a pixel with its neighbors,
% which gives a visual impression of where active cells are.

C = corrcovDiag(pixCov, diags);
actStd = std(abs(C), [], 2);
actMean = mean(abs(C), 2);

actImg = actMean/nanstd(actMean(:)) + actStd/nanstd(actStd(:));

actImg(isnan(actImg)) = 0;
actImg = reshape(actImg, h, w);
actImg = adapthisteq(actImg/max(actImg(:)), 'numtiles', [8 8]);