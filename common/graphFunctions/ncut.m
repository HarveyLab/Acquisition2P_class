function cost = ncut(W, A, B)
% cost = ncut(W, A, B) returns the cost of the normalized cut between the
% disjointed sets A and B in the graph with the edge weight matrix W. A and
% B are logical vectors into W. A and B must be non-overlapping, i.e.
% any(A&B)==false.

cost = cut(W, A, B)/assoc(W, A, A|B) + cut(W, A, B)/assoc(W, B, A|B);