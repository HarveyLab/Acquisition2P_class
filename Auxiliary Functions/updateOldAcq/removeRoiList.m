function removeRoiList(acq)
% removeRoiList(acq) updates the way that ROI information is stored.
if isfield(acq.roiInfo.slice(1), 'roiList')
    for sl = 1:numel(acq.roiInfo.slice)
        roiInfoOld = acq.roiInfo.slice(sl);
        
        for r = 1:numel(roiInfoOld.roi)
            roiId = acq.roiInfo.slice(sl).roiList(r);
            acq.roiInfo.slice(sl).roi(r).id = roiId;
            acq.roiInfo.slice(sl).roi(r).group = acq.roiInfo.slice(sl).grouping(roiId);
        end
    end
    
    % Remove all obsolete fields:
    acq.roiInfo.slice = rmfield(acq.roiInfo.slice, {'roiLabels', 'roiList', 'grouping'});
    
    warndlg('The data structure of your Acquisition2P object has been updated. Please save your object now.', 'Acq2P update', 'modal')
else
    warning('Your acq2p object does not have an roiList field. No changes made.')
end
end

