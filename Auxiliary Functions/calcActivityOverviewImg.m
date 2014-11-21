function actImg = calcActivityOverviewImg(pixCov, diags, h, w)
% actImg = calcActivityOverviewImg(pixCov, diags, h, w) calculates an image
% displaying the variance of the correlation of a pixel with its neighbors,
% which gives a visual impression of where active cells are.

actImg = var(corrcovDiag(pixCov, diags), [], 2);
actImg(isnan(actImg)) = 0;
actImg = reshape(actImg, h, w);
actImg = adapthisteq(actImg/max(actImg(:)));