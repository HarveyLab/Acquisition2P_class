function r = detectFullframeRecursive(mov, idx)

% Recursive full-frame alignment code from:
% https://scanbox.wordpress.com/2014/03/20/recursive-image-alignment-and-statistics/

if(length(idx)==1)
    A = mov(:, :, idx(1));
    r.m = A; % mean    
    r.T = [0 0]; % no translation (identity)
    r.n = 1; % # of frames
else
    idx0 = idx(1:floor(end/2)); % split into two groups
    idx1 = idx(floor(end/2)+1 : end);
    r0 = detectFullframeRecursive(mov,idx0); % align each group
    r1 = detectFullframeRecursive(mov,idx1);
    [u, v] = fftalign(r0.m,r1.m); % align their means
    r0.m = circshift(r0.m,[u v]); % shift mean
    delta = r1.m-r0.m; % online update of the moments (read the Pebay paper)
    na = r0.n;
    nb = r1.n;
    nx = na + nb;
    r.m = r0.m+delta*nb/nx;
    r.T = [(ones(size(r0.T,1),1)*[u v] + r0.T) ; r1.T]; % transformations
    r.n = nx; % number of images in A+B
end