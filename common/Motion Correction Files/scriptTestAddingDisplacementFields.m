moving = [1 2; 0 0];

Dx = [1 -1; 0 0];
Dy = [0 0; 0 0];
D = cat(3, Dx, Dy);

disp(imwarp(moving, D))

%% Test it
img = double(imread('cameraman.tif'));
[x_orig, y_orig] = meshgrid((0:255)-255/2);
C_orig = cat(3, x_orig, y_orig);
figure(1)
imagesc(img)
title('Original')

% Create affine tform:
theta = 15;
tform = affine2d([cosd(theta) -sind(theta) 0; sind(theta) cosd(theta) 0; 0 0 1]);
[x_affine, y_affine] = transformPointsInverse(tform, x_orig, y_orig);

% Apply affine tform:
D_affine = cat(3, x_affine-x_orig, y_affine-y_orig);
R = imref2d(size(img), [-127.7 127.5], [-127.7 127.5]);
img_affine = imwarp(img, R, tform, 'outputview', R);
figure(2)
imagesc(img_affine)
title('Affine')

% Create warping:
% r = randn(4, 4, 2);
D_nonrigid = imresize(r, size(img), 'bicubic') * 15;
img_nonrigid = imwarp(img_affine, D_nonrigid);
figure(3)
imagesc(img_nonrigid)
title('Affine, then nonrigid')

% Add displacement fields:
stk2comp = @(D) complex(D(:,:,1), D(:,:,2));
comp2stk = @(D) cat(3, real(D), imag(D));

% To add two displacement fields, we take the first and query it at the
% coordinates defined in the second:
tic
D_sum = interp2(x_orig, y_orig, stk2comp(D_affine+C_orig), ...
    x_orig+D_nonrigid(:,:,1), y_orig+D_nonrigid(:,:,2), 'cubic');
toc

D_sum = nan2zero(comp2stk(D_sum)-C_orig);
img_sum = imwarp(img, D_sum);
figure(4)
imagesc(img_sum)
title('Combined displacement fields')

figure(5)
imagesc(img_nonrigid-img_sum)
colorbar
title('Difference')


