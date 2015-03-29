function cost = cut(W, A, B)
% cost = cut(W, A, B) returns the cost of cutting between the disjointed
% sets A and B in the graph with the edge weight matrix W. A and B are
% logical vectors into W. A and B must be non-overlapping, i.e.
% any(A&B)==false.

cost = sum(sum(W(A(:), B(:))));