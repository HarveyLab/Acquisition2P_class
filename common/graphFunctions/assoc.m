function cost = assoc(W, A, V)
% cost = assoc(W, A, B) returns the association with set V of subset A. A and V are
% logical vectors into W. A must be a subset of V, i.e. isequal(A&V, A)==true.

if ~isequal(A&V, A)
    error('A must be a subset of V.');
end

cost = sum(sum(W(A(:), V(:)))) - sum(sum(W(A(:), A(:))))/2;