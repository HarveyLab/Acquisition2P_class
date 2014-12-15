function A = diag2full(B, d, m, n)
% A = diag2full(B, d, m, n) puts the columns of B on the diagonals d of
% of the m-by-n matrix A. Syntax like SPDIAGS, but non-sparse.

A = zeros(m, n);
diagInd = 1:m+1:m^2;
for ii = 1:numel(d)
    d_ = d(ii);
    
    if d_>=0
        A(diagInd(1+d_:end)-d_) = B(1+d_:end, ii);
    else
        A(diagInd(1:end+d_)-d_) = B(1:end+d_, ii);
    end
end