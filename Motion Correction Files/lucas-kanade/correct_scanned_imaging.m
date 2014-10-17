function [p, iter_used, corr, failed, settings, xpixelposition, ypixelposition, data_corrected, template_sampled] = ...
    correct_scanned_imaging(data,template_image,subrec,data_extra_channels,frame_list,settings,isbidirec,est_p,pregauss,leftexclude)
%correct_scanned_imaging
%
%Corrects horizontal motion artifacts in imaging acquired through a scanning process.
%Motion much faster than the imaging frame rate can be detected and corrected.
%
%Simplest posible use of this function:
%[p, ~, ~, ~, ~, ~, ~, data_corrected] = correct_scanned_imaging(data, template_image);
%
%Full range of possible inputs and outputs:
%[p, iter_used, corr, failed, settings, xpixelposition, ypixelposition, data_corrected, template_sampled] = ...
%   correct_scanned_imaging(data,template_image,subrec,data_extra_channels,frame_list,settings,isbidirec,est_p,pregauss)
%
%Inputs:
%data -- 3D array of double precision, h x w x n. n is the number of image
%frames. It is assumed that raster scanning has proceed along each row of
%data, and that there are h scan lines.
%
%template_image -- an image to which the data will be aligned. it need not be
%the same size as each image in data. in theory this should be an image
%without motion distortion
%
%subrec -- the rectangular region of template_image to which the raster scan
%was targeted. subrec is a vector of form [left right bottom top], and its
%values are pixel coordinates in template_image. The first two elements give the
%horizontal extent of the rectangle, and the second two its vertical extent.
%if subrec is omitted or empty, it will be assumed that the entire template_image
%was targeted in the raster scanning. The exception to this is when the numbers of rows in the
%imaging data and template are equal but the number of columns is leftexclude less (see below)
%in the imaging data, in which case it will be assumed that the non excluded columns of the imaging
%data match all columns of the template
%
%data_extra_channels -- extra image channels to be corrected according to the motion detected
%for the channel in data. must be a 4D array, with the first 3 dimensions matching data and
%the 4th dimension for image channel
%
%frame_list -- a list of frames to be corrected in the imaging file. default is all frames
%
%settings -- a structure whos fields contain parameters for motion
%correction. Either all the following subfields should be set, or the whole
%settings structure should be omitted or empty, in which case default
%values will be used. The subfields and their default values are:
%   *move_thresh (0.010) -- the converence threshold for changes in
%   estimated displacements in pixels
%   *corr_thresh (0.75) -- the minimum pearson's correlation value for a
%   successful converence
%   *max_iter (120) -- the maximum number of allowed Lucas-Kanade iterations
%   *scanlinesperparameter (2) -- the number of scanlines between displacement
%   stimations, and probably the most important parameter. Higher values
%   allow noiser data to be used, while lower values allow faster
%   displacement to be corrected.
%   *haltcorr (0.995) -- the correlation value for which no further
%   improvement will be attempted, even if the convergence criteria are not
%   met
%
%isbidirec -- was bidirectional scanning used (true or false), i.e. do even
%numbered scan lines go right to left instead of left to right. default false
%
%est_p -- estimated displacements to be used as seed values for gradient
%descent. est_p should have n rows and number of columns
%2 + 2 * floor(h / settings.scanlinesperparameter)
%est_p can be omitted or left empty. Whether or not est_p is given,
%displacements of zero will also be attempted as seed values.
%
%pregauss -- amount of Gaussian filtering to apply to data before motion-correcting it.
%
%leftexclude -- how many pixels to ignore at the left of the imaging data
%
%Outputs:
%p -- estimated displacement. Each row of p corresponds to one of the n
%images. For each image, the displaced position of the focus will be estimated
%1 + floor(h / settings.scanlinesperparameter) times per frame. the first
%half of each row contains these x displacement values, and the second half
%contains y displacement values. the units of the values are pixels of template_image
%
%iter_used -- the number of Lucas Kanade iterations used for each image.
%
%corr -- the final pearson's correlation value between each image and
%template_image after convergence.
%
%failed -- a vector containing 1's for images with failed convergence, 0's otherwise
%
%setttings -- the settings that were used for motion correction. This will
%contain the input settings and some additional fields. It can be used as
%an input to another call of motioncorrect.
%
%xpixelposition, ypixelposition -- the estimated positions of each pixel in
%data after motion correction. Its values are pixel coordinates in template_image.
%1st and 2nd dimensions are same as data, 3rd dimension corresponds to frame_list.
%
%data_corrected - corrected imaging, will be the same size as template_image
%with the 3rd dimension corresponding to frames and the 4th to image channels.
%For example, if data has a size of 100 on the 3rd dimensions and
%frame_list ranges from 51 to 60, then data_corrected will have a size of 10
%on the 3rd dimension.
%
%template_sampled - linearly interpolated values of the template image that correspond to
%each pixel of the motion-displaced data. size matches xpixelposition/ypixelposition
%
%--------------------------------------------------------------------------
%INFO
%For further details, see "Automated correction of fast motion artifacts for two-photon
%imaging of awake animals," D.S. Greenberg & J.N.D. Kerr, Journal of
%Neuroscience Methods, 2009.
%http://dx.doi.org/10.1016/j.jneumeth.2008.08.020
%
%Written and released by David S. Greenberg, Tuebingen, Germany, March 2009.
%Last updated September 5, 2013
%
%By usings this code you agree not to distribute it to anyone else, modify
%it and then distribute it, or publish the code............... brother.
%
%For general inquiries contact david@tuebingen.mpg.de or jason@tuebingen.mpg.de
%This code is not supported, feel free to submit questions, problems, or
%bug reports but a timely response may not be possible.
%
%As we are a curious bunch, please let us know if you modify it in a useful
%way, for richer or poorer etc etc
%David says: that he retains all commercial rights etc
%Jason says: he looks forward to seeing what it winds up being used for, if
%you send us your email we will send you updates and future modifications.........
%==========================================================================

%FIXME should use a standard input parser instead of all this code
if ~exist('data_extra_channels','var')
    data_extra_channels = [];
end
[data, template_image, data_extra_channels, sD, nlines, linewidth, nframes, nrows_template, ncols_template, n_extra_channels] = ...
    check_idata_inputsvars(data, template_image, data_extra_channels);
if ~exist('subrec','var') || isempty(subrec)
    if linewidth == ncols_template + leftexclude && nlines == nrows_template
        subrec = [1 - leftexclude ncols_template 1 nrows_template]; %assume the template is the same size and location as the non-excluded part of the image frames
    else
        subrec = [1 ncols_template 1 nrows_template]; %assume the template is the same size and location as the image frames
    end
end
if ~exist('isbidirec','var') || isempty(isbidirec)
    isbidirec = false;
end
if ~exist('pregauss','var') || isempty(pregauss)
    pregauss = 0;
end
if ~exist('leftexclude','var') || isempty(leftexclude)
    leftexclude = 0;
else
    assert(numel(leftexclude) == 1 && isnumeric(leftexclude) && ~isnan(leftexclude) && leftexclude == round(leftexclude) && imag(leftexclude) == 0 && ~isinf(leftexclude),'leftexclude must be a nonnegative interger');
    leftexclude = double(leftexclude);
end
if ~exist('settings','var')
    settings = []; %FIXME ought to to merge settings input with leftexclude, pregauss, bidirec etc. and allow some fields to be presents and others not
end
if ~exist('frame_list','var') || isempty(frame_list)
    frame_list = 1:nframes;
end
settings = init_settings(settings, nlines, linewidth, subrec, isbidirec, pregauss, leftexclude);
max_iter = settings.max_iter; move_thresh = settings.move_thresh; corr_thresh = settings.corr_thresh; haltcorr = settings.haltcorr; scanlinesperparameter = settings.scanlinesperparameter; nblocks = settings.nblocks; reltime = settings.reltime; blockt = settings.blockt; pregauss = settings.pregauss; basex = settings.basex; basey = settings.basey; blockind = settings.blockind; blockind2 = blockind + settings.nblocks + 1;

data = data(:,settings.leftexclude + 1:end,:);
data_extra_channels = data_extra_channels(:,settings.leftexclude+1:end,:,:);
if pregauss > 0
    data = prefilter_data(data, pregauss, sD, leftexclude);
end

if ~exist('est_p','var') || isempty(est_p)
    est_given = 0;
    est_p = [];
else
    assert(size(est_p, 1) == numel(frame_list), 'est_p must have as many rows as the number of imaging frames to be corrected')
    est_given = 1;
end

min_blockpoints_ratio = 0.3;
pointsperblock = scanlinesperparameter * size(data,2);
minpointsperblock = pointsperblock * min_blockpoints_ratio;

xgrad = [diff(template_image,1,2) nan(nrows_template, 1)];    ygrad = [diff(template_image,1,1); nan(1, ncols_template)]; %gradients. NaNs are appended so they can be indexed the same as the template.

failed = zeros(numel(frame_list), 1);
corr = zeros(numel(frame_list),1);
iter_used = zeros(numel(frame_list),1);
p = zeros(numel(frame_list), nblocks * 2 + 2);

frac = reltime / blockt;
comp = 1 - frac;

for ii = 1:numel(frame_list)
    j = frame_list(ii);
    T = reshape(data(:,:,j),[],1);
    %compile a list of choices for the intial warp parameters
    init_p = zeros(1, nblocks * 2 + 2); %choice 1: no displacement
    if est_given %choice 2: user-input estimated displacement for this frame
        init_p = [init_p; est_p(ii,:)]; %#ok<AGROW>
    end
    if ii > 1 && ~failed(ii - 1) && frame_list(ii) == frame_list(ii - 1) + 1 %choice 3: displacement at the end of the previous frame
        init_p = [init_p; est_fromlast]; %#ok<AGROW>
    end
    %now test each initial parameter estimate
    initcorr = -1 + zeros(size(init_p,1),1);
    for k = 1:size(init_p,1)
        testp = init_p(k,:);
        x = basex + testp(blockind) .* comp + testp(blockind + 1) .* frac;
        y = basey + testp(blockind2) .* comp + testp(blockind2 + 1) .* frac;
        
        [wI, mask2] = sample_template_image(x,y,template_image);      
        if any(mask2(:))
            pixperblock = histc(blockind(mask2),1:nblocks);
            if any(pixperblock >= minpointsperblock)
                initcorr(k) = quickcorr(wI(mask2),T(mask2));
            end
        end
    end
    %rank the initial parameter estimates in in descending order of correlation
    [~,sortind] = sort(initcorr);
    sortind = flipud(sortind);
    init_p = init_p(sortind,:);
    nextp = nan(size(init_p, 1), size(p,2));
    [nextcorr, nextiter_used] = deal(nan(1, size(init_p, 1)));
    nextmask = cell(1, size(init_p, 1));    
    for k = 1:size(init_p,1) %use the inital parameter estimates to start gradient descent until we exceed corr_thresh
        [nextp(k,:),nextcorr(k),nextiter_used(k),nextmask{k}] = align_frame_to_template(...
            T,template_image,init_p(k,:)',xgrad,ygrad,frac,blockind, basex, basey, minpointsperblock, max_iter, move_thresh, haltcorr, nblocks);
        if nextcorr(k) >= haltcorr
            break;
        end
    end
    [corr(ii), bestind] = max(nextcorr); %FIXME should probably optimize for mean squared error instead???
    p(ii,:) = nextp(bestind,:);
    iter_used(ii) = nextiter_used(bestind);
    mask = nextmask{bestind};    
    if corr(ii) >= corr_thresh %alignment successful
        blocksused = unique(blockind(mask));
        %interpolate. FIXME: we should actually combine info across multiple frames when doing this, and interpolate over missing sectoins within a frame
        firstblockused = min(blocksused);
        if firstblockused > 1
            initial_displacement = [p(ii, firstblockused) p(ii, firstblockused + nblocks + 1)]; %displacement at beginning of frame
            p(ii,  1:firstblockused - 1)                          = initial_displacement(1);
            p(ii, (1:firstblockused - 1) + nblocks + 1)           = initial_displacement(2);
        end
        lastblockused = max(blocksused);
        final_displacement = [p(ii, lastblockused + 1) p(ii, lastblockused + 1 + nblocks + 1)]; %displacement at end of frame
        if lastblockused < nblocks
            p(ii,  max(blocksused) + 1:nblocks + 1)                = final_displacement(1);
            p(ii, (max(blocksused) + 1:nblocks + 1) + nblocks + 1) = final_displacement(2);
        end
        %calculate an estimate of intial displacement we can use for the next frame if so desired
        est_fromlast = [repmat(p(ii, nblocks + 1),1,nblocks + 1) repmat(p(ii, end),1, nblocks + 1)];
    else %alignment failed
        failed(ii) = 1;
        p(ii,   :) = nan;
    end
end
if nargout > 5
    [xpixelposition, ypixelposition] = deal(nan([nlines linewidth - settings.leftexclude numel(frame_list)]));
    for ii = find(~failed)'
        nextp = p(ii,:);
        xpixelposition(:,:,ii) = basex + nextp(blockind) .* comp + nextp(blockind + 1) .* frac;
        ypixelposition(:,:,ii) = basey + nextp(blockind2) .* comp + nextp(blockind2 + 1) .* frac;
    end
end
if nargout > 7
    data_corrected = zeros([nrows_template ncols_template numel(frame_list) 1 + n_extra_channels]);
    data_corrected(:,:,:,1) = corrected_scanned_imaging(data,xpixelposition,ypixelposition,[nrows_template ncols_template],frame_list);
    for ecind = 1:n_extra_channels
        data_corrected(:,:,:,1 + ecind) = corrected_scanned_imaging(data_extra_channels(:,:,:,ecind),xpixelposition,ypixelposition,[nrows_template ncols_template],frame_list);
    end
end
if nargout > 8
    template_sampled = zeros([nlines linewidth - settings.leftexclude numel(frame_list)]);
    for ii = find(~failed)'
        template_sampled(:,:,ii) = sample_template_image(xpixelposition(:,:,ii),ypixelposition(:,:,ii),template_image);
    end
end

function [data, template_image, data_extra_channels, sD, nlines, linewidth, nframes, nrows_template, ncols_template, n_extra_channels] = ...
    check_idata_inputsvars(data, template_image, data_extra_channels)
idata_inputvars = {'data', 'template_image', 'data_extra_channels'};
for kk = 1:numel(idata_inputvars)
    assert(eval(['isnumeric(' idata_inputvars{kk} ')']), [idata_inputvars{kk} ' must be numeric']);
    assert(eval(['~isempty(' idata_inputvars{kk} ')']), [idata_inputvars{kk} ' must be nonempty']);
    assert(eval(['~any(isnan(' idata_inputvars{kk} '(:)))']), [idata_inputvars{kk} ' cannot contain NaN values']);
    assert(eval(['~any(isinf(' idata_inputvars{kk} '(:)))']), [idata_inputvars{kk} ' cannot contain infinite values']);
    if ~eval(['isa( ' idata_inputvars{kk} ',''double'')'])
        warning('correct_scanned_imaging:idata_inputvar2double',['Converting ' idata_inputvars{kk} ' from type ' class(data) ' to double']);
        eval([idata_inputvars{kk} ' = double(' idata_inputvars{kk} ');']);
    end
end
sD = size(data); sD(end+1:3) = 1; nlines = sD(1); linewidth = sD(2); nframes = sD(3);
nrows_template = size(template_image,1); ncols_template = size(template_image,2);
assert(size(template_image,1) * size(template_image,2) == numel(template_image), 'template_image must be a single image');
n_extra_channels = 0;
if ~isempty(data_extra_channels)
    assert(size(data_extra_channels, 1) == sD(1) && size(data_extra_channels, 2) == sD(2) && size(data_extra_channels, 3) == sD(3),...
        'size along the first 3 dimensions of data and data_extra_channels must match');
    n_extra_channels = size(data_extra_channels,4);
end

function [p,corr,iter,mask] = align_frame_to_template(T,I,est_p,xgrad,ygrad,frac,blockind,basex, basey, minpointsperblock, max_iter, move_thresh, haltcorr, nblocks)
framew = size(basex,2); frameh = size(basex,1);
blocksize = ceil(numel(basex) / nblocks); %number of pixels per block, possibly not including last block
%reorder matrices so that each column corresponds to one linear segment of the interpolated trajectories
blockind = blockorder(blockind, blocksize, framew, frameh);
blockind(~blockind) = 1; %this allows us to use blockind as an index without indexing blockind itself, to increase speed. the resulting bogus values will be masked out later
basex = blockorder(basex, blocksize, framew, frameh);
basey = blockorder(basey, blocksize, framew, frameh);

frac = blockorder(frac, blocksize, framew, frameh);
T = blockorder(T, blocksize, framew, frameh);

p = est_p;
delta_p = zeros(size(p));
iter = 0;

ratefac = 1;
nparampoints = nblocks + 1;
nparams = 2 * nparampoints;
H = spalloc(nparams, nparams, 4 * (nparampoints + nparampoints - 1 + nparampoints - 1));

diagindx = 1:(nparams+1):nparams * nparampoints - nparampoints;
offdiagindLx = diagindx(1:end-1) + 1;
offdiagindUx = diagindx(1:end-1) + nparams;

%store indices into the pseudo-Hessian matrix corresponding to different groups of parameters
Dshift = nparampoints;
Rshift = nparams * nparampoints;

diagindy = diagindx + Dshift + Rshift;
offdiagindLy = offdiagindLx + Dshift + Rshift;
offdiagindUy = offdiagindUx + Dshift + Rshift;

diagindxyL = diagindx + Dshift;
offdiagindLxyL = offdiagindLx + Dshift;
offdiagindUxyL = offdiagindUx + Dshift;

diagindxyU = diagindx + Rshift;
offdiagindLxyU = offdiagindLx + Rshift;
offdiagindUxyU = offdiagindUx + Rshift;

H(diagindx) = 0; H(diagindy) = 0; H(offdiagindLx) = 0; H(offdiagindLy) = 0;
H(diagindxyL) = 0; H(offdiagindLxyL) = 0; H(offdiagindLxyU) = 0;
H(diagindxyU) = 0; H(offdiagindUxyL) = 0; H(offdiagindUxyU) = 0;

comp = 1 - frac;
fracsq = frac.^2;
compsq = comp.^2;
fcprod = comp .* frac;

templatew = size(I,2); templateh = size(I,1);

blocks_present = false(nparampoints,1);
blocked = 1:max(blockind(:));
blockind2 = blockind + nparampoints;

x = basex + p(blockind) .* comp + p(blockind + 1) .* frac;
y = basey + p(blockind2) .* comp + p(blockind2 + 1) .* frac;
mask = (x > 1 + eps) & (x < templatew - eps) & (y > 1 + eps) & (y < templateh - eps);

if ~any(mask)
    blocks_present(:) = false;
else
    pixperblock = histc(blockind(mask),blocked);
    blocks_present = pixperblock >= minpointsperblock;
    mask(pixperblock(blockind) < minpointsperblock) = 0; %do we really want to do this? FIXME
end
if ~any(blocks_present)
    corr = nan; return;
end
mask_comp = ~mask;
param_points_used = [blocks_present(1); blocks_present(1:end-1) | blocks_present(2:end); blocks_present(end)];
params_used = [param_points_used; param_points_used];

x_int = floor(x);
y_int = floor(y);
matind = y_int + templateh * (x_int - 1);
x_frac = x - x_int;
y_frac = y - y_int;
x_frac_comp = 1 - x_frac;
y_frac_comp = 1 - y_frac;
matind(mask_comp) = 1; %use placeholder values for points that are masked out (not used) so we don't need an indexing operation
%precalculate indices to be used for warping
matindp1 = matind + 1;
matindpth = matind + templateh;
matindpthp1 = matindpth + 1;
%now compute the image value at the warped coordinates from the surrounding 4 pixels' values, using a 4-way weighted average
wI = x_frac_comp .* ((y_frac_comp) .* I(matind) + ...
    y_frac .* I(matindp1)) + ...
    x_frac .* ((y_frac_comp) .* I(matindpth) + ...
    y_frac .* I(matindpthp1));
difference_image = T - wI; %calculate difference image by subtracting template from warped frame
difference_image(mask_comp) = 0;
errval = mean(difference_image(:) .^ 2);
corr = quickcorr(wI(mask), T(mask));
while (iter <= max_iter)
    iter = iter + 1;
    % --- we now calculate the direction and size of the optimal update to p based on gradients etc.: ---
    
    %sample gradients
    wxgrad = y_frac_comp .* xgrad(matind) + y_frac .* xgrad(matindp1);
    wygrad = x_frac_comp .* ygrad(matind) + x_frac .* ygrad(matindpth);
    %set these to zero now so we don't have to index later
    wxgrad(mask_comp) = 0; wygrad(mask_comp) = 0;
    
    %precalcuations:
    wxgradsq = wxgrad.^2;
    wygradsq = wygrad.^2;
    wxygrad = wxgrad .* wygrad;
    %Calculate the pseudo-Hessian matrix:
    %x-x diagonal
    H(diagindx) = [sum(wxgradsq .* compsq) 0] + [0 sum(wxgradsq .* fracsq)]; %#ok<*SPRIX>
    %x-x off-diagonal
    offdiag = sum(wxgradsq .* fcprod);
    H(offdiagindLx) = offdiag;
    H(offdiagindUx) = offdiag;
    %y-y diagonal
    H(diagindy) = [sum(wygradsq .* compsq) 0] + [0 sum(wygradsq .* fracsq)];
    %y-y off-diagonal
    offdiag = sum(wygradsq .* fcprod);
    H(offdiagindLy) = offdiag;
    H(offdiagindUy) = offdiag;
    %x-y diagonal
    diagon = [sum(wxygrad .* compsq) 0] + [0 sum(wxygrad .* fracsq)];
    H(diagindxyL) = diagon;
    H(diagindxyU) = diagon;
    %x-y off-diagonal
    offdiag = sum(wxygrad .* fcprod);
    H(offdiagindLxyL) = offdiag;
    H(offdiagindUxyL) = offdiag;
    H(offdiagindLxyU) = offdiag;
    H(offdiagindUxyU) = offdiag;
    %calculate the vector v which will be multiplied by the inverse pseudo-hessian to yield the new delta_p
    v = [[sum(wxgrad .* comp .* difference_image) 0] + [0 sum(wxgrad .* frac .* difference_image)] ...
        [sum(wygrad .* comp .* difference_image) 0] + [0 sum(wygrad .* frac .* difference_image)]]';
    %invert H and multiply by v, ignoring unused parameters
    delta_p(:) = 0;
    delta_p(params_used) = ratefac * H(params_used, params_used) \ v(params_used);
    
    nscale = 0;
    while true
        pnew = p + delta_p;
        
        x = basex + pnew(blockind) .* comp + pnew(blockind + 1) .* frac;
        y = basey + pnew(blockind2) .* comp + pnew(blockind2 + 1) .* frac;
        mask = (x > 1 + eps) & (x < templatew - eps) & (y > 1 + eps) & (y < templateh - eps);
        if ~any(mask)
            blocks_present(:) = false;
        else
            pixperblock = histc(blockind(mask),blocked);
            blocks_present = pixperblock >= minpointsperblock;
            mask(pixperblock(blockind) < minpointsperblock) = 0; %do we really want to do this? FIXME
        end
        if ~any(blocks_present)
            delta_p = delta_p * 0.5; continue;
        end
        mask_comp = ~mask;
        param_points_used = [blocks_present(1); blocks_present(1:end-1) | blocks_present(2:end); blocks_present(end)];
        params_used = [param_points_used; param_points_used];
        
        x_int = floor(x);
        y_int = floor(y);
        matind = y_int + templateh * (x_int - 1);
        x_frac = x - x_int;
        y_frac = y - y_int;
        x_frac_comp = 1 - x_frac;
        y_frac_comp = 1 - y_frac;
        matind(mask_comp) = 1; %use placeholder values for points that are masked out (not used) so we don't need an indexing operation
        %precalculate indices to be used for warping
        matindp1 = matind + 1;
        matindpth = matind + templateh;
        matindpthp1 = matindpth + 1;
        %now compute the image value at the warped coordinates from the surrounding 4 pixels' values, using a 4-way weighted average
        wI = x_frac_comp .* ((y_frac_comp) .* I(matind) + ...
            y_frac .* I(matindp1)) + ...
            x_frac .* ((y_frac_comp) .* I(matindpth) + ...
            y_frac .* I(matindpthp1));
        difference_image = T - wI; %calculate difference image by subtracting template from warped frame
        difference_image(mask_comp) = 0;
        errvalnew = mean(difference_image(:) .^ 2);
        if errvalnew <= errval || all(abs(delta_p) < move_thresh)
            break;
        end
        delta_p = delta_p * 0.5;
        nscale = nscale + 1;
    end
    if errvalnew > errval
        break;
    end
    p = pnew; errval = errvalnew;
    corr = quickcorr(wI(mask), T(mask));
    if corr >= haltcorr
        break;
    end
end
%reconvert the mask to the original indexing format:
maskconvmat = false(size(wI));
maskconvmat(mask) = true;
invbomat = invblockorder(maskconvmat, framew, frameh);
mask = find(invbomat);

function [wI,mask] = sample_template_image(x,y,I)
templatew = size(I,2); templateh = size(I,1);
mask = (x > 1 + eps) & (x < templatew - eps) & (y > 1 + eps) & (y < templateh - eps); %we need a buffer of 1 extra pixel since we need to sample the gradients as well as the image
mask_comp = ~mask;
x_int = floor(x);
y_int = floor(y);
matind = y_int + templateh * (x_int - 1);
x_frac = x - x_int;
y_frac = y - y_int;
x_frac_comp = 1 - x_frac;
y_frac_comp = 1 - y_frac;
matind(mask_comp) = 1; %use placeholder values for points that are masked out (not used) so we don't need an indexing operation
%precalculate indices to be used for warping
matindp1 = matind + 1;
matindpth = matind + templateh;
matindpthp1 = matindpth + 1;
%now compute the image value at the warped coordinates from the surrounding 4 pixels' values, using a 4-way weighted average
wI = x_frac_comp .* ((y_frac_comp) .* I(matind) + ...
    y_frac .* I(matindp1)) + ...
    x_frac .* ((y_frac_comp) .* I(matindpth) + ...
    y_frac .* I(matindpthp1));

function y = blockorder(x, blocksize, w, h)
x = reshape(x,h,w);
y = zeros(blocksize, ceil(w * h / blocksize));
y(1:w*h) = x';

function y = invblockorder(x, w, h)
y = reshape(x(1:w*h),w,h)';

function q = quickcorr(a,b)
n = size(a,1);
a = a - sum(a) / n;
b = b - sum(b) / n;
assq = a' * a;
bssq = b' * b;
q = a' * b;
q = q / sqrt(assq * bssq);

function data = prefilter_data(data, pregauss, sD, leftexclude)
%prefilter data
L = ceil(sqrt((2*pregauss^2) * log(10000 / (sqrt(2*pi)*pregauss)))); %.0001 > 1/(sqrt(2*pi)*pregauss * exp(L^2/(2*pregauss^2)))
sbig = sD(1:2) + [0 -leftexclude] + L;
[x,y] = meshgrid(1:sbig(2),1:sbig(1));
g2d = exp( - (min(x - 1, sbig(2) + 1 - x).^2 + min(y - 1, sbig(1) + 1 - y).^2) / (2 * pregauss^2) );
g2d = g2d / sum(sum(g2d));
g2d = fft2(g2d,sbig(1),sbig(2));
for k = 1:size(data,3)
    u = real(ifft2(fft2(data(:,:,k),sbig(1),sbig(2)) .* g2d));
    data(:,:,k) = u(1:sD(1),1:sD(2) - leftexclude);
end

function settings = init_settings(settings, nlines, linewidth, subrec, isbidirec, pregauss, leftexclude) %initialize settings structure
if isempty(settings)
    settings = struct('move_thresh',0.010,'corr_thresh',0.75,'max_iter',120,'scanlinesperparameter',2,'pregauss',pregauss,'haltcorr',0.995,'bidirec',isbidirec,'leftexclude',leftexclude);
else
    %should check that it's a valid structure FIXME
end
settings.nblocks = max(floor(nlines / settings.scanlinesperparameter),1);
settings.blockt = settings.scanlinesperparameter / nlines;
settings.lastblockt = 1 - settings.blockt * (settings.nblocks - 1);
settings.blocke = 1 : settings.scanlinesperparameter : nlines + 1;
settings.blocke(end) = nlines + 1;
[~,settings.blockind] = histc(repmat((1:nlines)', 1, linewidth),settings.blocke);
settings.reltime = (repmat(1:linewidth,nlines,1) + repmat(linewidth * (0:nlines - 1)',1,linewidth) - 0.5) / (linewidth * nlines); %FIXME: this is an approximation that ignores e.g. flyback time at the end of each line/frame
settings.reltime = settings.reltime - (settings.blockind - 1) * settings.blockt;
if settings.bidirec
    settings.reltime(2:2:end,:) = fliplr(settings.reltime(2:2:end,:));
end
settings.basex = subrec(1) + (0:(linewidth-1)) * (subrec(2) - subrec(1)) / (linewidth - 1);
settings.basex = repmat(settings.basex,nlines,1);
settings.basey = subrec(3) + (0:(nlines-1))' * (subrec(4) - subrec(3)) / (nlines - 1);
settings.basey = repmat(settings.basey,1,linewidth);
jj = settings.leftexclude+1:linewidth;
[settings.basex, settings.basey, settings.reltime, settings.blockind] = deal(settings.basex(:,jj), settings.basey(:,jj), settings.reltime(:,jj), settings.blockind(:,jj));

function d = corrected_scanned_imaging(data,xpixelposition,ypixelposition,template_image_size,frame_list)
[d, n] = deal(zeros([template_image_size numel(frame_list)]));
for k = 1:numel(frame_list)
    [d(:,:,k), n(:,:,k)] = pushgrid(d(:,:,k), xpixelposition(:,:,k), ypixelposition(:,:,k), data(:,:,frame_list(k)), n(:,:,k));
end
d = d ./ n;

function [z,n] = pushgrid(z,x,y,d,n) %add d to z in a grid-weighted way at (x,y) and record it in n
nrows_template = size(z,1);
ncols_template = size(z,2);

mask = find((x >= 1) & (x < ncols_template) & (y >= 1) & (y < nrows_template));
x = x(mask);
y = y(mask);
d = d(mask);

x_int = floor(x); y_int = floor(y);
x_frac = x - x_int; y_frac = y - y_int;
matind = y_int + nrows_template * (x_int - 1);

%"bilinear-like" interpolation:
z(matind) = z(matind) + (1 - x_frac) .* (1 - y_frac) .* d;
z(matind + 1) = z(matind + 1) + (1 - x_frac) .* y_frac .* d;
z(matind + nrows_template) = z(matind + nrows_template) + x_frac .* (1 - y_frac) .* d;
z(matind + nrows_template + 1) = z(matind + nrows_template + 1) + x_frac .* y_frac .* d;

%keeping track of denominator weights for final normalization:
n(matind + 1) = n(matind + 1) + (1 - x_frac) .* y_frac;
n(matind + nrows_template) = n(matind + nrows_template) + x_frac .* (1 - y_frac);
n(matind) = n(matind) + (1 - x_frac) .* (1 - y_frac);
n(matind + nrows_template + 1) = n(matind + nrows_template + 1) + x_frac .* y_frac;