function [corrected, xshift, yshift] = correct_translation_singleframe(moving, ref, isRefPrecalcd, movingFullSize)
% Translate a single frame to match a reference, using subpixel FFT
% registration.

if nargin < 4
    movingFullSize = moving;
end

% Find shifts:
if nargin<3 || ~isRefPrecalcd
    ref_fft = zeros(size(ref, 1), size(ref, 2), 3);
    ref_fft(:,:,1) = fft2(ref);
    ref_fft(:,:,2) = fftshift(ref_fft(:,:,1));
    ref_fft(:,:,3) = conj(ref_fft(:,:,1));
else
    ref_fft = ref;
end

upsamplingFac = 50; % This needs to be >= 50 for accurate widefield results.
output = dftregistration(fft2(moving), ref_fft(:,:,1), ref_fft(:,:,2), ref_fft(:,:,3), upsamplingFac);
xshift = output(4);
yshift = output(3);

% Translate:
% tformMat = eye(3);
% tformMat(3, 1) = xshift;
% tformMat(3, 2) = yshift;
% tform = affine2d(tformMat);
% 
% corrected = imwarp(movingFullSize, tform, ...
%     'OutputView', imref2d(size(movingFullSize)), 'FillValues', 0); 

[h, w] = size(movingFullSize);
corrected = interp2(movingFullSize, (1:w)-xshift, ((1:h)-yshift)', 'linear', 0);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function output = dftregistration(mov_fft, ref_ftt, ref_fftshift, ref_conj, usfac)
% function [output Greg] = dftregistration(buf1ft,buf2ft,usfac);
% Efficient subpixel image registration by crosscorrelation. This code
% gives the same precision as the FFT upsampled cross correlation in a
% small fraction of the computation time and with reduced memory 
% requirements. It obtains an initial estimate of the crosscorrelation peak
% by an FFT and then refines the shift estimation by upsampling the DFT
% only in a small neighborhood of that estimate by means of a 
% matrix-multiply DFT. With this procedure all the image points are used to
% compute the upsampled crosscorrelation.
% Manuel Guizar - Dec 13, 2007

% Portions of this code were taken from code written by Ann M. Kowalczyk 
% and James R. Fienup. 
% J.R. Fienup and A.M. Kowalczyk, "Phase retrieval for a complex-valued 
% object by using a low-resolution image," J. Opt. Soc. Am. A 7, 450-458 
% (1990).

% Citation for this algorithm:
% Manuel Guizar-Sicairos, Samuel T. Thurman, and James R. Fienup, 
% "Efficient subpixel image registration algorithms," Opt. Lett. 33, 
% 156-158 (2008).

% Inputs
% buf1ft    Fourier transform of reference image, 
%           DC in (1,1)   [DO NOT FFTSHIFT]
% buf2ft    Fourier transform of image to register, 
%           DC in (1,1) [DO NOT FFTSHIFT]
% usfac     Upsampling factor (integer). Images will be registered to 
%           within 1/usfac of a pixel. For example usfac = 20 means the
%           images will be registered within 1/20 of a pixel. (default = 1)

% Outputs
% output =  [error,diffphase,net_row_shift,net_col_shift]
% error     Translation invariant normalized RMS error between f and g
% diffphase     Global phase difference between the two images (should be
%               zero if images are non-negative).
% net_row_shift net_col_shift   Pixel shifts between images
% Greg      (Optional) Fourier transform of registered version of buf2ft,
%           the global phase difference is compensated for.

% Partial-pixel shift:

% First upsample by a factor of 2 to obtain initial estimate
% Embed Fourier data in a 2x larger array
[m,n]=size(ref_ftt);

mlarge=m*2;
nlarge=n*2;


%todo: do this outside of the loop.
CC=zeros(mlarge,nlarge);
CC(m+1-fix(m/2):m+1+fix((m-1)/2),n+1-fix(n/2):n+1+fix((n-1)/2)) = ...
    ref_fftshift.*conj(fftshift(mov_fft));
% CC = ref_fftshift.*conj(fftshift(mov_fft));

% Compute crosscorrelation and locate the peak 
CC = ifft2(ifftshift(CC)); % Calculate cross-correlation

[max1,loc1] = max(CC);
[~,loc2] = max(max1);
rloc=loc1(loc2);
cloc=loc2;
CCmax=CC(rloc,cloc);

% Obtain shift in original pixel grid from the position of the
% crosscorrelation peak 
[m,n] = size(CC);
md2 = fix(m/2); nd2 = fix(n/2);
if rloc > md2 
    row_shift = rloc - m - 1;
else
    row_shift = rloc - 1;
end
if cloc > nd2
    col_shift = cloc - n - 1;
else
    col_shift = cloc - 1;
end
row_shift=row_shift/2;
col_shift=col_shift/2;

% If upsampling > 2, then refine estimate with matrix multiply DFT
if usfac > 2,
    %%% DFT computation %%%
    % Initial shift estimate in upsampled grid
    row_shift = (row_shift*usfac)/usfac; 
    col_shift = (col_shift*usfac)/usfac;     
    dftshift = ((usfac*1.5)/2); %% Center of output array at dftshift+1
    % Matrix multiply DFT around the current shift estimate
    CC = conj(dftups(mov_fft.*ref_conj,(usfac*1.5),(usfac*1.5),usfac,...
        dftshift-row_shift*usfac,dftshift-col_shift*usfac))/(md2*nd2*usfac^2);
    % Locate maximum and map back to original pixel grid 
    [max1,loc1] = max(CC);   
    [~,loc2] = max(max1); 
    rloc = loc1(loc2); cloc = loc2;
    CCmax = CC(rloc,cloc);
    rg00 = dftups(ref_ftt.*ref_conj,1,1,usfac)/(md2*nd2*usfac^2);
    rf00 = dftups(mov_fft.*conj(mov_fft),1,1,usfac)/(md2*nd2*usfac^2);  
    rloc = rloc - dftshift - 1;
    cloc = cloc - dftshift - 1;
    row_shift = row_shift + rloc/usfac;
    col_shift = col_shift + cloc/usfac;    

% If upsampling = 2, no additional pixel shift refinement
else    
    rg00 = sum(sum( ref_ftt.*ref_conj ))/m/n;
    rf00 = sum(sum( mov_fft.*conj(mov_fft) ))/m/n;
end
error = 1.0 - CCmax.*conj(CCmax)/(rg00*rf00);
error = sqrt(abs(error));
diffphase=atan2(imag(CCmax),real(CCmax));

output=[error,diffphase,row_shift,col_shift];

% % Compute registered version of buf2ft
% % col_shift = round(col_shift);
% % row_shift = round(row_shift);
% if (nargout > 1)&&(usfac > 0),
%     [nr,nc]=size(mov_fft);
%     Nr = ifftshift([-fix(nr/2):ceil(nr/2)-1]);
%     Nc = ifftshift([-fix(nc/2):ceil(nc/2)-1]);
%     [Nc,Nr] = meshgrid(Nc,Nr);
%     Greg = mov_fft.*exp(1i*2*pi*(-row_shift*Nr/nr-col_shift*Nc/nc));
%     Greg = Greg*exp(1i*diffphase);
% elseif (nargout > 1)&&(usfac == 0)
%     Greg = mov_fft*exp(1i*diffphase);
% end
return

function out = dftups(in,nor,noc,usfac,roff,coff)
% function out=dftups(in,nor,noc,usfac,roff,coff);
% Upsampled DFT by matrix multiplies, can compute an upsampled DFT in just
% a small region.
% usfac         Upsampling factor (default usfac = 1)
% [nor,noc]     Number of pixels in the output upsampled DFT, in
%               units of upsampled pixels (default = size(in))
% roff, coff    Row and column offsets, allow to shift the output array to
%               a region of interest on the DFT (default = 0)
% Recieves DC in upper left corner, image center must be in (1,1) 
% Manuel Guizar - Dec 13, 2007
% Modified from dftus, by J.R. Fienup 7/31/06

% This code is intended to provide the same result as if the following
% operations were performed
%   - Embed the array "in" in an array that is usfac times larger in each
%     dimension. ifftshift to bring the center of the image to (1,1).
%   - Take the FFT of the larger array
%   - Extract an [nor, noc] region of the result. Starting with the 
%     [roff+1 coff+1] element.

% It achieves this result by computing the DFT in the output array without
% the need to zeropad. Much faster and memory efficient than the
% zero-padded FFT approach if [nor noc] are much smaller than [nr*usfac nc*usfac]

[nr,nc]=size(in);
% Set defaults
if exist('roff', 'var')~=1, roff=0; end
if exist('coff', 'var')~=1, coff=0; end
if exist('usfac', 'var')~=1, usfac=1; end
if exist('noc', 'var')~=1, noc=nc; end
if exist('nor', 'var')~=1, nor=nr; end

% Compute kernels and obtain DFT by matrix products
kernc=exp((-1i*2*pi/(nc*usfac))*( ifftshift((0:nc-1)).' - floor(nc/2) )*( (0:noc-1) - coff ));
kernr=exp((-1i*2*pi/(nr*usfac))*( (0:nor-1).' - roff )*( ifftshift((0:nr-1)) - floor(nr/2)  ));
out=kernr*in*kernc;
return