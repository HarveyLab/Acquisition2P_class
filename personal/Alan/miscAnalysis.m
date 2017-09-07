%% Normalize Raw Fluorescence to Peaks

dFnorm = bsxfun(@rdivide,dF,max(dF,[],2));


%% Plot Simple Heatmap with Strain Underneath

%strainScale = 0:.001:((numel(strain)-1)/1000); %1kHz sampling; can get
%this from h5 file

fig1 = figure;
subplot(4,1,1:3)
imagesc(dFnorm_brush)
set(gca,'xtick',[])
ylabel('ROI')
subplot(4,1,4)
plot(WS_brushScale,WS_brushStrain)
xlim([min(WS_brushScale) max(WS_brushScale)])
xlabel('Time (s)')
ylabel('Strain')
set(gca,'ytick',[])



%% Plot Heatmap with Aurora Trace Underneath


fig1 = figure;
subplot(4,1,1:3)
imagesc(dF_steps2)
set(gca,'xtick',[])
ylabel('ROI')
subplot(4,1,4)
plot(reshape(WS_steps2Force_duringAcq(:,[2:10 12:20]),360000,1))
xlim([0 360000])
xlabel('Time (ms)')
ylabel('Force')


%% Plot ROIs with Selectivity for Paw or Thigh Brushing

roiMatrix = zeros(512,512);
for n = 1:length(roiSelectivity)
    roiMatrix(roiList_brush(n).indBody(~isnan(roiList_brush(n).indBody))) = roiSelectivity(n);
end
fig2 = figure;
imagesc(roiMatrix)
colormap(gray)
pbaspect([1 1 1])
set(gcf,'units','inches')
pos = get(gcf,'position');
set(gcf,'position',[pos(1) pos(2) 5 5])
cbar = colorbar('position',[.92 .45 .02 .1]);
set(gca,'XTick',[])
set(gca,'YTick',[])
set(cbar,'Ticks',[-1 1])
set(cbar,'TickLabels',{'Paw','Thigh'})