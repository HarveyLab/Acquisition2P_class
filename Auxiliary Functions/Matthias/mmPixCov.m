function pixCov = mmPixCov(mov, nh)

temporalBin = 8;

mov = mov(:,:,1:end-rem(end, temporalBin)); % Deal with movies that are not evenly divisible.
movSize = size(mov);
[h, w, z] = size(mov);
z = z/temporalBin;
mov = squeeze(sum(reshape(mov,movSize(1)*movSize(2),temporalBin,movSize(3)/temporalBin),2));
mov = bsxfun(@minus,mov,mean(mov,2));

nPix = w*h;

% Neighborhood is square, and the edge length must be odd:
% nh = 2*radiusPxCov+1;

% Create an adjacency matrix for the first pixel. An adjacency matrix is an
% nPixel-by-nPixel matrix that is 1 if pixel i and j are within a
% neighborhood (i.e. we need to calculate their covariance), and 0
% elsewhere. In our case, this matrix has a characterisitic pattern with
% sparse bands that run parallel to the diagonal. Because nPix-by-nPix is
% large, we simply assemble a list of linear indices:

% ...Make list of diagonals in adjacency matrix that are 1, following
% the convention of spdiags();
diags = row(bsxfun(@plus, (-nh+1:nh-1)', 0:h:h*(nh-1)));
diags(diags<0) = [];
nDiags = numel(diags);

% Calculate covariance:
pixCov = zeros(nPix, nDiags, 'single');

parfor ii = 1:nDiags
    pairingsHere = circshift(mov, [-diags(ii), 0]);
    pixCov(:, ii) = sum(mov .* pairingsHere, 2)/z;
end

% Shift into spdiags format:
for ii = 1:nDiags
    pixCov(:, ii) = circshift(pixCov(:, ii), diags(ii));
end