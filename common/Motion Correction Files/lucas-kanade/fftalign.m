function [u,v] = fftalign(ref, img)
% [u,v] = fftalign(A,B)
% From http://scanbox.wordpress.com/2014/03/20/recursive-image-alignment-and-statistics/

% Make sure images have even width and height:
ref = ref(1:end-mod(end, 2), 1:end-mod(end, 2));
img = img(1:end-mod(end, 2), 1:end-mod(end, 2));

N = min(size(ref));

% Make images square:
yidx = round(size(ref,1)/2)-N/2 + 1 : round(size(ref,1)/2)+ N/2;
xidx = round(size(ref,2)/2)-N/2 + 1 : round(size(ref,2)/2)+ N/2;
 
ref = ref(yidx,xidx);
img = img(yidx,xidx);
 
C = fftshift(real(ifft2(fft2(ref).*fft2(rot90(img,2)))));
[~,i] = max(C(:));
[ii, jj] = ind2sub(size(C),i);
 
u = N/2-ii;
v = N/2-jj;