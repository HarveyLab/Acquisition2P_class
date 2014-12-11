function cbShowROITrace(sel, ~, ~, roiId)

%get the roiInfo
roiInfo = sel.roiInfo.roi([sel.roiInfo.roi.id]==roiId);

%plot
sel.plotNeuropilTraces(roiInfo.indBody, roiInfo.indNeuropil, false);

end