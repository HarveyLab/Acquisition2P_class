function diags = getDiags(nh, h)
% diags = getDiags(nh, h) returns a vector indicating which diagonals of
% the covariance matrix will be non-zero for an image of height h and a
% square pixel neighborhood of width h.

diags = row(bsxfun(@plus, (-nh+1:nh-1)', 0:h:h*(nh-1)));
diags(diags<0) = [];