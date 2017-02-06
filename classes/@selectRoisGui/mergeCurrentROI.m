function mergeCurrentROI(sel)

isMerging = strcmp('Select cluster to merge with', ...
    get(get(sel.h.ax.cluster, 'Title'), 'string'));

if ~isMerging
    sel.disp.clus2merge = sel.disp.currentClustInd;
    title(sel.h.ax.cluster,'Select cluster to merge with'),
elseif isMerging
    ind2merge = sel.disp.currentClustering == sel.disp.clus2merge;
    sel.disp.currentClustering(ind2merge) = sel.disp.currentClustInd;
    sel.disp.currentClustering(sel.disp.currentClustering > sel.disp.clus2merge) = ...
        sel.disp.currentClustering(sel.disp.currentClustering > sel.disp.clus2merge) - 1;
    % Update Displays
    if sel.disp.currentClustInd > sel.disp.clus2merge
        sel.disp.currentClustInd = sel.disp.currentClustInd-1;
    end
    set(sel.h.img.cluster, 'cdata', label2rgb(sel.disp.currentClustering));
    title(sel.h.ax.cluster, ...
        sprintf('Cluster %1.0f Merged',sel.disp.clus2merge)),
    sel.displayRoi,
end