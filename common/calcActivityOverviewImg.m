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

function [R,sigma] = corrcovDiag(B, diags)
%CORRCOVDIAG Compute correlation matrix from covariance matrix (in diagonal
%form).
%   R = CORRCOV(C) computes the correlation matrix R that corresponds to the
%   covariance matrix C, by standardizing each row and column of C using the
%   square roots of the variances (diagonal elements) of C.  C is square,
%   symmetric, and positive semi-definite.  The correlation for a constant
%   variable (zero diagonal element of C) is undefined.
%
%   [R,SIGMA] = CORRCOV(C) computes the vector of standard deviations SIGMA
%   from the diagonal elements of C.

% Get SD = sqrt(var)
sigma = sqrt(B(:, diags==0));

% Divide by sigma_i times sigma_j:
R = bsxfun(@rdivide, B, sigma);

for ii = 1:numel(diags)
    R(:, ii) = R(:, ii)./circshift(sigma, [diags(ii), 0]);
end

% Fix up possible round-off problems, while preserving NaN: put exact 1 on the
% diagonal, and limit off-diag to [-1,1]
t = find(abs(R) > 1);
R(t) = R(t)./abs(R(t));

R(:, diags==0) = sign(R(:, diags==0));