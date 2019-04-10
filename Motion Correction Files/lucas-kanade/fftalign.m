function [u,v] = fftalign(A,B)
% [u,v] = fftalign(A,B)
% From http://scanbox.wordpress.com/2014/03/20/recursive-image-alignment-and-statistics/
[h, w] = size(A);
 
% yidx = round(size(A,1)/2)-N/2 + 1 : round(size(A,1)/2)+ N/2;
% xidx = round(size(A,2)/2)-N/2 + 1 : round(size(A,2)/2)+ N/2;
 
% A = A(yidx,xidx);
% B = B(yidx,xidx);
 
C = fftshift(real(ifft2(fft2(A).*fft2(rot90(B,2)))));
[~,i] = max(C(:));
[ii, jj] = ind2sub(size(C),i);
 
u = round(h/2-ii);
v = round(w/2-jj);