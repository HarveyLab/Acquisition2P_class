function getBaseline_ransac_demo(sel)

% Load cell body and neuropil fluorescence
mov = sel.movMap.Data.mov;
fBodyRaw = mean(mov(:, sel.acq.mat2binInd(sel.nh2movInd(sel.disp.indBody))), 2)';
fNpRaw = mean(mov(:, sel.acq.mat2binInd(sel.nh2movInd(sel.disp.indNeuropil))), 2)';
f = fBodyRaw - fNpRaw*sel.disp.neuropilCoef(2);

clear mov

%% 

figure(9)
clf
subplot(2, 1, 1)
hold on
% plot(fBodyRaw)
plot(f, 'displayname', 'raw F')

% filtf = sgolayfilt(f,1,31);

% Offset of fit:
% plot(filtf);

% Explanation of approach: We want to find the regions of the trace that
% are (a) well fit by a straight line and (b) have a slope of about zero.
% We can calculate the x-frame least squares fit for all frames by
% computing an x frame moving average (sgolayfilt of order 1). The slope
% will then be the difference between frame i and frame i+x. The residual
% of the fit is the x-frame moving average of the squared difference
% between the original fluoresence trace and the smoothed trace. now we
% have offset, slope and residual for each x-frame stretch in the trace. we
% can now somehow fit a baseline to all the points with small/zero slope
% and small fit residuals, e.g. using a robust fit. alternatively, we could
% do something more clever (ransac or something bayesian?).

% Bad old version:
% % Slope of fit:
% slope = circshift(filtf, [0 7])-circshift(filtf, [0 -7]);
% plot(slope)
% 
% % Residual of fit:
% resid = sgolayfilt((f-filtf).^2,1,15);
% % plot(resid)
% 
% % ind = randi(numel(f), 30, 1);
% 
% iFlat = abs(slope)<0.3 & resid < 10;

% Good version with real linear regression:
halfWinSize = 30;
winSize = 2*halfWinSize+1;

% Linear regression via normal equation:
% X = ones(winSize, 2)/winSize;
% X(:, 2) = (-halfWinSize:halfWinSize)/winSize;
% M = X'*X\X';

% Calculate sliding dot product (=xcorr):
% intercept = conv(f, M(1, :), 'same');
% slope = -conv(f, M(2, :), 'same');
% 
% fHat = (conv(intercept, X(:, 1), 'same') - conv(slope, X(:, 2), 'same'))/winSize;
% resid = sqrt(conv((f-fHat).^2, X(:, 1), 'same'));
% 
% iFlat = abs(slope)<6 & resid < prctile(resid, 10);
hold on

% plot(find(iFlat), f(iFlat), '.k', 'displayname', 'Local lin reg inliers')


% ind = find(iFlat);

% % Add first and last datapoints so that fit is anchored, in case there are
% % no good flat bits there:
% ind(end+1:end+2) = [1, numel(iFlat)];

% f_ = fitExpLin(f(ind), ind, numel(f));
% plot(f_);
% 
% f_ = fitExpLin(fHat(ind), ind, numel(f));
% plot(f_, 'displayname', 'Local linear regression');


[f_, stats] = getBaseline_customWeightFun(f);

inliers = f;
inliers(stats.w~=1) = nan;
plot(inliers, 'k', 'displayname', 'Custom wfun inliers');

% fsmmoth = conv(f, ones(60, 1)/60, 'same');
% plot(fsmmoth, 'displayname', 'smooth F')

plot(f_, 'displayname', 'Custom wfun in robustfit');

% ind_downSampled = 1:1:numel(f);
% f_downSampled = f(1:1:end);
% plot(ind_downSampled(stats.w==1), f_downSampled(stats.w==1), 'm.', 'displayname', 'Custom wfun inliers');



% plot(f-f_+max(f)*1.3, 'b', 'displayname', 'deltaF');
% plot(f*0+max(f)*1.3, 'k', 'displayname', 'deltaF');

f__ = getF_(f, 'exp_linear');
plot(f__, 'displayname', 'getFbaseline');

% plot(stats.resid)

% f__ = getF_talwar(f, 'exp_linear');
% plot(f__, ':', 'displayname', 'getFbaseline (Talwar weights)');

% xlim([1, 75000])
axis off

subplot(2, 1, 2)
hold on
plot(f, 'displayname', 'raw F')
plot(inliers, 'k', 'displayname', 'Custom wfun inliers');
plot(f_, 'displayname', 'Custom wfun in robustfit');
plot(f__, 'displayname', 'getFbaseline');
xlim([60000 68000]);
axis off

% legend toggle

% figure(1324)
% plot(slope, f, '.k', 'markersize', 1)


% function ransac(f)
% nSamples = 10;
% minFracInlier = 0.4;
end



function [f_, stats] = fitExpLin(f, t, nT, isCustWfun)

if nargin < 4
    isCustWfun = false;
end

x = 2*(t./nT)-1; 
xExp = exp(-x);

downSamplingStep = 1;

function w = wfun(r)
   % Take average across winSize frames:
   winSize = 60/downSamplingStep;
%    win = ones(winSize, 1)/winSize;
%    r  = conv(r, win, 'same');
   
   r = imdilate(r, ones(winSize, 1)); % imdilate = running max filter
   
   % Choose weights such that there are some inliers everywhere:
   
%    % Start with very exclusive criterion:
%    w = 1 * (r.^2<1); % Talwar weights.
%    
%    % Calculate distance of each point from closest inlier:
%    dist = bwdist(w);
%    
%    
%    % Thin out the distance measure so that we don't get heavy blocks of
%    % points that are all designated inliers just because they are far away
%    % from other points:
%    distScale = dist*0;
%    distScale(1:30/downSamplingStep:end) = dist(1:30/downSamplingStep:end);
%    
%    % Relax criterion based on distance:
%    distScale = distScale/(3600/downSamplingStep); % 3600 = 2 minutes
% %    distScale(distScale<1) = 1;
%    
%    w = 1 * (r.^2<distScale);
%    
%    w = 1 * (conv(w, ones(winSize, 1), 'same') > 0);

    % Choose weights such that the inliers are evenly distributed on a long
    % timescale:
    
%     rSmooth = conv(r, ones(3600, 1)/3600, 'same');
%     rThresh = runningPrctileMat(r, 3600, 180);
    
    
    nR = numel(r);
    rOrig = r;
    r(end+3600-rem(nR, 3600)) = 0;
    r = reshape(r, 3600, []);
    thresh = prctile(r, 10, 1);
    thresh = repmat(thresh, 3600, 1);
    thresh = thresh(1:nR)';
    
    w = 1 * (rOrig < thresh);
   
end

%    warning('todo: thin out the weights so that there are no regions with heavily clustered weights')
   
if isCustWfun
    % The robust fit with the custom weight function is pretty slow, but we
    % could easily write a stripped down robustfit function (the core code
    % is simple) that uses fewer iterations or some
    % approximation/downsampling.
    [b, stats] = robustfit([x(1:downSamplingStep:end)',xExp(1:downSamplingStep:end)'],f(1:downSamplingStep:end)', @wfun, 1.5);
else
    % Use talwar weighing function: This assigns weight 0 to all outliers,
    % which should be more robust than assigning some finite weight to them.
    [b, stats] = robustfit([x(:),xExp(:)],f(:), 'talwar', 1);
end

xHat = linspace(-1,1, nT);
xHatExp = exp(-xHat);
f_ = [ones(nT, 1) ,xHat', xHatExp'] * b;
f_ = f_';
end