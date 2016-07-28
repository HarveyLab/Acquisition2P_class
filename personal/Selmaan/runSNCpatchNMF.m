function runSNCpatchNMF(data,saveFile)

%% Set parameters
sizY = size(data,'Y');                  % size of data matrix
patch_size = [54,54];                   % size of each patch along each dimension (optional, default: [32,32])
overlap = [8,8];                        % amount of overlap in each dimension (optional, default: [4,4])

patches = construct_patches(sizY(1:end-1),patch_size,overlap);
p = 1;                                            % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)
merge_thr = 0.8;                                  % merging threshold

options = CNMFSetParms(...
    'd1',sizY(1),'d2',sizY(2),...
    'search_method','ellipse','dist',3,...      % search locations when updating spatial components
    'deconv_method','constrained_foopsi',...    % activity deconvolution method
    'temporal_iter',2,...                       % number of block-coordinate descent steps 
    'ssub',1,...
    'tsub',6,...
    'fudge_factor',0.98,...                     % bias correction for AR coefficients
    'merge_thr',merge_thr,...                    % merging threshold
    'gSig',4,...
    'nB',1, ...
    'medw',[1 1]);
options.temporal_iterFinal = options.temporal_iter;
%% Get Patches Results

RESULTS = patch_CNMF_SNC(data,patches,p,options,1);

parfor patchNum = 2:length(patches)
    patchNum,
    RESULTS(patchNum) = patch_CNMF_SNC(data,patches,p,options,patchNum);
end


%% combine results into one structure
fprintf('Combining results from different patches...');
d = prod(sizY(1:2));
A = sparse(d,length(patches)*size(RESULTS(1).A,2));
P.sn = zeros(sizY(1:2));
P.active_pixels = zeros(sizY(1:2));
IND = zeros(sizY(1:2));
P.b = {};
P.c1 = {};
P.gn = {};
P.neuron_sn = {};
P.psdx = zeros(patches{end}(2),patches{end}(4),size(RESULTS(1).P.psdx,2));
P.pFinal = p;

cnt = 0;
B = sparse(prod(sizY(1:end-1)),length(patches));
MASK = zeros(sizY(1:2));
F = zeros(length(patches),sizY(end));
for i = 1:length(patches)
    for k = 1:size(RESULTS(i).A,2)
            cnt = cnt + 1;
            Atemp = zeros(sizY(1:2));
            Atemp(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) = ...
                reshape(RESULTS(i).A(:,k),patches{i}(2)-patches{i}(1)+1,patches{i}(4)-patches{i}(3)+1);            
            A(:,cnt) = sparse(Atemp(:));
    end
    
    b_temp = sparse(sizY(1),sizY(2));
    b_temp(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) = reshape(RESULTS(i).b,patches{i}(2)-patches{i}(1)+1,patches{i}(4)-patches{i}(3)+1);  
    B(:,i) = b_temp(:);
    F(i,:) = RESULTS(i).f;
    %     b_temp = zeros(sizY(1),sizY(2),options.nb);
%     for numBackG = 1:options.nb
%         b_temp(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4),numBackG) = ...
%             reshape(RESULTS(i).b(:,numBackG),patches{i}(2)-patches{i}(1)+1,patches{i}(4)-patches{i}(3)+1);
%         B(:,numBackG,i) = reshape(b_temp(:,:,numBackG),prod(sizY(1:2)),1);
%         F(numBackG,:,i) = RESULTS(i).f(numBackG,:);
%     end
    MASK(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) = MASK(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) + 1;
    P.sn(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) = reshape(RESULTS(i).P.sn,patches{i}(2)-patches{i}(1)+1,patches{i}(4)-patches{i}(3)+1);
    P.active_pixels(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) = P.active_pixels(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) + ...
        reshape(RESULTS(i).P.active_pixels,patches{i}(2)-patches{i}(1)+1,patches{i}(4)-patches{i}(3)+1);
    IND(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) = IND(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4)) + 1;
    P.psdx(patches{i}(1):patches{i}(2),patches{i}(3):patches{i}(4),:) = reshape(RESULTS(i).P.psdx,patches{i}(2)-patches{i}(1)+1,patches{i}(4)-patches{i}(3)+1,[]);

%     P.b = [P.b;RESULTS(i).P.b];
%     P.c1 = [P.c1;RESULTS(i).P.c1];
%     P.gn = [P.gn;RESULTS(i).P.gn];
%     P.neuron_sn = [P.neuron_sn;RESULTS(i).P.neuron_sn];
end

A = spdiags(1./MASK(:),0,prod(sizY(1:2)),prod(sizY(1:2)))*A;
B = spdiags(1./MASK(:),0,prod(sizY(1:2)),prod(sizY(1:2)))*B;
C = cell2mat({RESULTS(:).C}');
A(A<0) = 0;
B(B<0) = 0;
C(C<0) = 0;
F(F<0) = 0;

fprintf(' done. \n');
clear RESULTS

% %% estimate active pixels
% fprintf('Classifying pixels...')
% X = P.psdx(:,:,1:min(size(P.psdx,2),500));
% X = reshape(X,[],size(X,ndims(X)));
% X = bsxfun(@minus,X,mean(X,2));     % center
% X = spdiags(std(X,[],2)+1e-5,0,size(X,1),size(X,1))\X;
% [L,Cx] = kmeans_pp(X',2);
% [~,ind] = min(sum(Cx(max(1,end-49):end,:),1));
% P.active_pixels = (L==ind);
% P.centroids = Cx;
% fprintf(' done. \n');


%% Initialize common background
fin = mean(F);
for iter = 1:150
    fin = diag(sqrt(sum(fin.^2,2)))\fin;
    bin = max(B*(F*fin')/(fin*fin'),0);
    fin = max((bin'*bin)\(bin'*B)*F,0);
end

% fSplit(1,:) = medfilt1(fin,1e3,'truncate');
% fSplit(2,:) = fin-fSplit(1,:);
% fin = fSplit;
% bin = repmat(bin,1,2);
b = bin;
f = fin;
%% Merge sources and eliminate very weak sources
fracRetain = 0.9;
nSources = size(A,2);
P.b = cell(nSources,1);
P.c1 = cell(nSources,1);
P.gn = cell(nSources,1);
P.neuron_sn = cell(nSources,1);

Km = 0;
Kn = nSources;

while Km < Kn
    Kn = size(A,2);
    [A,C] = merge_components([],A,bin,C,fin,P,[],options);
    Km = size(A,2),
end

[A,C] = order_ROIs(A,C);

numRetain = ceil(fracRetain*size(A,2));
A = A(:,1:numRetain);
C = C(1:numRetain,:);
P.b = cell(numRetain,1);
P.c1 = cell(numRetain,1);
P.gn = cell(numRetain,1);
P.neuron_sn = cell(numRetain,1);
%% update spatial and temporal components
P.p = 0; % Don't model temporal dynamics on first pass
options.temporal_iter = 1; %Don't use multiple iterations on first pass
fprintf('Updating spatial components... (1)');
warning('off','MATLAB:nargchk:deprecated'),
[A,b,C] = update_spatial_components(data,C,f,A,P,options);
fprintf(' done. \n');
fprintf('Updating temporal components... (1)')
[C,f,P,S,YrA] = update_temporal_components(data,A,b,C,fin,P,options);
fprintf(' done. \n');

%% Merge Components
fprintf('Merging overlaping components... (1)')
Km = 0;
Kn = size(A,2);

while Km < Kn
    Kn = size(A,2);
    [A,C,~,~,P,S] = merge_components([],A,b,C,f,P,S,options);
    Km = size(A,2),
end
fprintf(' done. \n');

% %% Order ROIs and exclude inactive components
% [Am,Cm,Sm,Pm] = order_ROIs(Am,Cm,Sm,Pm);
% warning('Ordering needs to be reworked...'),
% orderThresh = 600;
% 
% Am = Am(:,1:orderThresh);
% Cm = Cm(1:orderThresh,:);
% Sm = Sm(1:orderThresh,:);

%% Update components again and merge
P.p = P.pFinal; % P.p was set to 0 for first spatio-temporal update
fprintf('Updating Spatial components (2)... ')
[A,b,C] = update_spatial_components(data,C,f,A,P,options);
fprintf(' done. \n');
fprintf('Updating temporal components (2)... ')
[C,f,P,S,YrA] = update_temporal_components(data,A,b,C,f,P,options);
fprintf(' done. \n');
fprintf('Merging overlaping components... (2)')
Km = 0;
Kn = size(A,2);
while Km < Kn
    Kn = size(A,2);
    [A,C,~,~,P,S] = merge_components([],A,b,C,f,P,S,options);
    Km = size(A,2),
end
fprintf(' done. \n');
%% Final spatio-temporal update
fprintf('Updating spatial components (3)...');
options.temporal_iter = options.temporal_iterFinal; %Use multiple iterations for final pass
[A,b,C] = update_spatial_components(data,C,f,A,P,options);
fprintf(' done. \n');
fprintf('Updating temporal components (3)... ')
[C,f,P,S,YrA] = update_temporal_components(data,A,b,C,f,P,options);
fprintf(' done. \n');

%% Save Results
if ~isempty(saveFile)
    save(saveFile,'A','b','C','f','P','S','YrA'),
end