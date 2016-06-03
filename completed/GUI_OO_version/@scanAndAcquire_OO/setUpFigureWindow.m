function setUpFigureWindow(obj)
	% Set up the figure window for displaying data as they stream in

	obj.figureHandles.fig = clf;
	set(obj.figureHandles.fig ,'CloseRequestFcn', @obj.figCloseAndStopScan );

	%Create axes for each channel
	for ii=1:length(obj.inputChans)
		obj.figureHandles.channel(ii).imAx=subplot(1,length(obj.inputChans),ii); %This axis will house the image
		obj.figureHandles.channel(ii).hAx=imagesc(zeros(obj.imSize)); %blank image
		set(obj.figureHandles.channel(ii).hAx,'Tag',sprintf('ch%02d',obj.inputChans(ii)))

		%Create axis into which we will place a histogram of pixel value intensities
		pos = get(obj.figureHandles.channel(ii).imAx,'Position');
		pos(3) = pos(3)*0.33;
		pos(4) = pos(4)*0.175;
		obj.figureHandles.channel(ii).histAx = axes('Position', pos);
	end

	%Tweak settings on axes and figure elemenents
	set([obj.figureHandles.channel(:).imAx], ...
		'XTick', [], ...
		'YTick', [], ...
		'CLim', [0,obj.AIrange]) 

	colormap gray

	%Expand figure window with number of channels
	pos=get(obj.figureHandles.fig,'Position');
	figSize = pos(3) * length(obj.inputChans);
	screenSize = get(0,'ScreenSize');
	if figSize > screenSize(3)
		figSize = screenSize(3);
	end
	pos(3) = figSize;
	set(obj.figureHandles.fig,'Position',pos);

end %close setUpFigureWindow
