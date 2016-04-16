function [aligned, dpxAl, dpyAl, B] = doLucasKanadeSPMD(stackFull, ref, isGpu)

% Parts of the Lucas Kanade motion correction code were obtained from 
% https://xcorr.net/2014/08/02/non-rigid-deformation-for-calcium-imaging-frame-alignment/
% and/or are originally based on the method published in:
% Greenberg, David S., and Jason N.D. Kerr. “Automated Correction of Fast
% Motion Artifacts for Two-Photon Imaging of Awake Animals.” Journal of
% Neuroscience Methods 176, no. 1 (January 15, 2009): 1–15.
% doi:10.1016/j.jneumeth.2008.08.020.

% If not set explicitly, then use GPU if available:
if ~exist('isGpu', 'var')
    isGpu = gpuDeviceCount > 0;
end

if isGpu && ~gpuDeviceCount
    warning('User requested GPU processing, but no GPU was found. Running on CPU.');
    isGpu = 0;
end

% Slice data into chunks to prevent GPU from filling up:
if isGpu
    gpu = gpuDevice;
    pctRunOnAll reset(gpuDevice);
    wait(gpuDevice)
    memAvailable = gpu.AvailableMemory;
    
    stackInfo = whos('stackFull');
    memFactor = 3; % We need memory equal to this many times the size of the stack.
    memRequired = memFactor*stackInfo.bytes;
    
    if memAvailable<memRequired
        % Split stack into chunks of ~equal size:
        nChunks = ceil(memRequired/memAvailable);
        [h, w, z] = size(stackFull);
        chunkSize = ceil(z/nChunks);
        chunkSizes = zeros(1, nChunks)+chunkSize;
        chunkSizes(end) = z-(nChunks-1)*chunkSize;
        stackChunked = mat2cell(stackFull, h, w, chunkSizes);
    else
        stackChunked = {stackFull};
    end    
else
    stackChunked = {stackFull};
end

% Process chunks:
nChunks = numel(stackChunked);
dpxAl = cell(1, nChunks);
dpyAl = cell(1, nChunks);
for s = 1:nChunks
    fprintf('Processing chunk %1.0f of %1.0f...\n', s, nChunks);
    [stackChunked{s}, dpxAl{s}, dpyAl{s}, B] = ...
        doLucasKanadeSPMD_chunk(stackChunked{s}, ref, isGpu);
end

% De-chunk:
fprintf('Retrieving data from workers...\n')
aligned = cell2mat(stackChunked);
dpxAl = cell2mat(dpxAl);
dpyAl = cell2mat(dpyAl);
end

function [aligned, dpxAl, dpyAl, B] = doLucasKanadeSPMD_chunk(stackFull, ref, isGpu)
stack = Composite();
nWorkers = numel(stack);
for i = 1:nWorkers
   stack{i} = stackFull(:,:,i:nWorkers:end);
end

% Parameters:
nBasis = 4;

% Precalculate constants:
[h, w, z] = size(stackFull);
nIters = nan(z, 1, 'like', stackFull);
minIters = 5;

knots = linspace(1, h, nBasis+1);
knots = [knots(1)-(knots(2)-knots(1)),knots,knots(end)+(knots(end)-knots(end-1))];
spl = fastBSpline(knots,knots(1:end-2));
B = spl.getBasis((1:h)');
B = cast(full(B), 'like', stackFull);
Bi = B(:,1:end-1).*B(:,2:end);
allBs = [B.^2,Bi];

Tnorm = ref(:) - mean(ref(:));
Tnorm = Tnorm/sqrt(sum(Tnorm.^2));
Tnorm = Tnorm(:);

lambda = .0001*median(ref(:))^2;
theI = (eye(nBasis+1, 'like', stackFull)*lambda);

[xi,yi] = meshgrid(1:w, 1:h);

spmd
    z = size(stack, 3);
    
    % First, we use a parfor loop to quickly calculate the initial block
    % shifts (this is slow on the GPU):
    if labindex==1
        fprintf('Calculating coarse shifts.\n')
        dispInterval = ceil(z/10);
    end
    dpx = zeros(nBasis+1, z, 'like', stack);
    dpy = zeros(nBasis+1, z, 'like', stack);
    for f = 1:z
        [dpx_, dpy_] = doBlockAlignment(stack(:,:,f), ref, nBasis);
        dpx(:, f) = [dpx_(1); (dpx_(1:end-1)+dpx_(2:end))/2; dpx_(end)];
        dpy(:, f) = [dpy_(1); (dpy_(1:end-1)+dpy_(2:end))/2; dpy_(end)];
    end

    if labindex==1
        fprintf('Calculating sub-pixel shifts:\n');
    end
    if isGpu
        % Send data to GPU:
        dpx_g = gpuArray(dpx);
        dpy_g = gpuArray(dpy);
        B_g = gpuArray(B);
        allBs_g = gpuArray(allBs);
        theI_g = gpuArray(theI);
        ref_g = gpuArray(ref);
        stack_g = gpuArray(stack);
        xi_g = gpuArray(xi);
        yi_g = gpuArray(yi);
        Tnorm_g = gpuArray(Tnorm);
        for f = 1:z
            if labindex==1 && ~mod(f, dispInterval);
                fprintf('%2.0f%%...\n', 100*f/z);
            end
            [stack_g(:,:,f), dpx_g(:,f), dpy_g(:,f), nIters(f)] = doLucasKanade_singleFrame(...
                ref_g, stack_g(:,:,f), dpx_g(:, f), dpy_g(:, f), minIters, ...
                B_g, allBs_g, xi_g, yi_g, theI_g, Tnorm_g, nBasis);
        end

        % Get data from GPU:
        stack = gather(stack_g);
        dpx = gather(dpx_g);
        dpy = gather(dpy_g);
    else
        for f = 1:z
            if labindex==1 && ~mod(f, dispInterval);
                fprintf('%2.0f%%...\n', 100*f/z);
            end
            [stack(:,:,f), dpx(:,f), dpy(:,f), nIters(f)] = doLucasKanade_singleFrame(...
                ref, stack(:,:,f), dpx(:, f), dpy(:, f), minIters, ...
                B, allBs, xi, yi, theI, Tnorm, nBasis);
        end
    end
end

% Retrieve aligned data:
if isGpu
    wait(gpuDevice);
end
stack = gather(stack);
aligned = zeros(size(stackFull), 'like', stackFull);
dpxAl = zeros(nBasis+1, size(stackFull, 3), 'like', stackFull);
dpyAl = zeros(nBasis+1, size(stackFull, 3), 'like', stackFull);
for i = 1:nWorkers
    aligned(:,:,i:nWorkers:end) = stack{i};
    dpxAl(:,i:nWorkers:end) = dpx{i};
    dpyAl(:,i:nWorkers:end) = dpy{i};
end

fprintf(' Done.\n');
end

function [Id, dpx, dpy, ii] = doLucasKanade_singleFrame(...
    T, I, dpx, dpy, minIters, ...
    B, allBs, xi, yi, theI, Tnorm, nBasis)

    warning('off','fastBSpline:nomex');
    maxIters = 50;
    deltacorr = 0.0005;
    [~, w] = size(T);
    
    %Find optimal image warp via Lucas Kanade    
    c0 = mycorr(I(:), Tnorm);
    
    for ii = 1:maxIters
        %Displaced template
        Dx = repmat((B*dpx), 1, w);
        Dy = repmat((B*dpy), 1, w);
        
        Id = interp2(I,xi+Dx,yi+Dy,'linear', 0);
                
        %gradient
        [dTx, dTy] = imgradientxy(Id, 'centraldifference');
        dTx(:, [1, end]) = 0;
        dTy([1, end], :) = 0;
        
        if ii > minIters
            c = mycorr(Id(:), Tnorm);
            if c - c0 < deltacorr && ii > 1
                break;
            end
            c0 = c;
        end
 
        del = T - Id;
 
        %special trick for g (easy)
        gx = B'*sum(del.*dTx, 2);
        gy = B'*sum(del.*dTy, 2);
 
        %special trick for H - harder
        Hx = constructH(allBs'*sum(dTx.^2,2), nBasis+1) + theI;
        Hy = constructH(allBs'*sum(dTy.^2,2), nBasis+1) + theI;
 
        dpx = dpx + Hx\gx;
        dpy = dpy + Hy\gy;
        
        % no damping
%         dpx = dpx + damping*dpx_;
%         dpy = dpy + damping*dpy_;
    end
end

function thec = mycorr(A,B)
    meanA = mean(A(:));
    A = A(:) - meanA;
    A = A / sqrt(sum(A.^2));
    thec = A'*B;
end
 
function H2 = constructH(Hd,ns)
%     H2d1 = Hd(1:ns)';
%     H2d2 = [Hd(ns+1:end);0]';
%     H2d3 = [0;Hd(ns+1:end)]';
%     
%     if isa(Hd, 'gpuArray')
%         H2 = gpuArray.zeros(ns);
%     else
%         H2 = zeros(ns);
%     end
%             
%     H2((0:ns-1)*ns+(1:ns)) = H2d1;
%     H2(((1:ns-1)*ns+(1:ns-1))) = H2d2(1:end-1);
%     H2(((0:ns-2)*ns+(1:ns-1))+1) = H2d3(2:end);

    if isa(Hd, 'gpuArray')
        H2 = gpuArray.zeros(ns);
    else
        H2 = zeros(ns);
    end
            
    H2((0:ns-1)*ns+(1:ns)) = Hd(1:ns)';
    H2(((1:ns-1)*ns+(1:ns-1))) = Hd(ns+1:end)';
    H2(((0:ns-2)*ns+(1:ns-1))+1) = Hd(ns+1:end)';
end
 
function [dpx,dpy] = doBlockAlignment(T, I, nBlocks)
    if isa(T, 'gpuArray')
        dpx = zeros(nBlocks,1);
        dpy = zeros(nBlocks,1);
        [h, w] = size(T);
    else
        dpx = zeros(nBlocks,1);
        dpy = zeros(nBlocks,1);
        [h, w] = size(T);
    end
 
    blockSize = h/nBlocks;
    xCenter = (w/2+1);
    yCenter = (floor(blockSize/2+1));
     
    for ii = 1:nBlocks
        lower = (ii-1)*blockSize+1;
        upper = lower-1+blockSize;
        T_ = T(lower:upper,:);
        I_ = I(lower:upper,:);
        
        T_ = bsxfun(@minus,T_,mean(T_,1));
        I_ = bsxfun(@minus,I_,mean(I_,1));
        dx = fftshift(ifft2(fft2(T_).*conj(fft2(I_))));
        [~,i] = max(dx(:));
        [yy, xx] = ind2sub([blockSize, w], gather(i));
        
        dpx(ii) = xx-xCenter;
        dpy(ii) = yy-yCenter;
    end
end