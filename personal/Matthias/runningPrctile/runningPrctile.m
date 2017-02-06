function A = runningPrctile(A, winSize, prctile)
% runningPrctile(A, winSize, prctile)

assert(isvector(A), 'A must be a vector')
assert(winSize>=1 && winSize<=numel(A) && round(winSize)==winSize, ...
    'winSize must be an integer between 1 and numel(A)');
assert(prctile>=0 && prctile <=100, 'prctile must be between 0 and 100')

nth = ceil((winSize/100)*prctile);
A = runningPrctileMex(A, winSize, nth);

% Fix edges (this is quick and dirty, implement it in mex file at some
% point!):
A(1:winSize) = A(winSize+1);
A(end-winSize+1:end) = A(end-winSize);