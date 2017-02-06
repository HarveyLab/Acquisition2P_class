function calcClusterProps(sel)

doCuts = get(sel.h.ui.autoCalcCuts,'Value');
doClusters = get(sel.h.ui.autoCalcClusters,'Value');

if doCuts
    cutVals = sel.disp.cutVals;
    X = 1:length(cutVals);
    warnState = warning('off', 'stats:statrobustfit:IterationLimit');
    [B,stats] = robustfit(X,cutVals,'bisquare',2);
    warning(warnState);
    Y = X*B(2)+B(1)-stats.robust_s*10;
    nCutsAuto = find(cutVals<Y,1,'last');
    if ~isempty(nCutsAuto)
        sel.disp.clusterNum = nCutsAuto;
    end
    
%     figure(6),
%     clf
%     hold on
%     plot(cutVals,'.','markerSize',15),
%     plot(X(nCutsAuto),cutVals(nCutsAuto),'.','markerSize',15),
%     plot(X,X*B(2)+B(1));
%     plot(X,Y);
%    figure(1),
end

if doClusters
    nCuts = sel.disp.clusterNum;
    corrSpace = sel.disp.cutVecs(:,1:nCuts);
    clusterMods = nCuts + (-1:1) + 1;
    clusterMods(clusterMods<2) = [];

    for nMod = 1:length(clusterMods)    
        nClusters = clusterMods(nMod);
        clusterIdx = getClusters(sel, nCuts, nClusters);
        s(nMod) = mean(silhouette(corrSpace,clusterIdx,'cityblock'));
    end

    [~,maxMod] = max(s);
    clusterMod = clusterMods(maxMod) - 1 - nCuts;
    clusterMod = max(clusterMod, 0); % Don't allow nCluster to be <= nCuts, because that's rarely a good guess.
    sel.disp.clusterMod = clusterMod;   
end

% figure(6),
% plot(clusterMods,s,'.','markerSize',15)

% figure(1),    
    
% critClust = 0;
% kNeighbors = 5;
% clusThresh = .075;
% clustResults = [];
% prevResult = nan;    
%     D = squareform(pdist(corrSpace));
%     %normD = D./repmat(sum(D,1),size(D,1),1);
%     [~,sortPts] = sort(D,1,'ascend');
%     neiPts = sortPts(2:kNeighbors+1,:);
%     neiClus = clusterIdx(neiPts);
%     simClus = repmat(clusterIdx',kNeighbors,1) ~= neiClus;
%     clustScore = zeros(nClusters,1);
%     for nCluster = 1:nClusters
%         clustIdx = clusterIdx == nCluster;
%         clustScore(nCluster) = mean(mean(simClus(:,clustIdx),1),2);
%     end
%     currentResult = max(clustScore) > clusThresh;
%     if isnan(prevResult)
%         prevResult = currentResult;
%     end
%     
%     if currentResult > prevResult
%         clusterMod = clusterMod-1;
%         break
%     elseif currentResult < prevResult
%         break
%     end
%     
%     if  currentResult
%         prevResult = 1;
%         clusterMod = clusterMod-1;
%     elseif ~currentResult
%         prevResult = 0;
%         clusterMod = clusterMod+1;
%     end
% end

