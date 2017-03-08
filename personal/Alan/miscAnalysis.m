%% Normalize Raw Fluorescence to Peaks

dFnorm = bsxfun(@rdivide,dF,max(dF,[],2));


%% Plot Simple Heatmap with Strain Underneath

%strainScale = 0:.001:((numel(strain)-1)/1000); %1kHz sampling; can get
%this from h5 file

fig1 = figure;
subplot(4,1,1:3)
imagesc(dFnorm)
set(gca,'xtick',[])
ylabel('ROI')
subplot(4,1,4)
plot(strainScale,strain)
xlim([min(strainScale) max(strainScale)])
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