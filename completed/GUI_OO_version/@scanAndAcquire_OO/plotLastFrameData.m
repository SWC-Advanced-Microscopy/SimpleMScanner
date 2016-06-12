
function plotLastFrameData(obj)
	% Plots data from the last frame
	%
	% TODO: Might want to remove the plotting from the class

	for chan = 1:size(obj.imageDataFromLastFrame,3)
		im = obj.imageDataFromLastFrame(:,:,chan);
		set(obj.figureHandles.channel(chan).hAx, 'CData', im) %Update image
		hist(obj.figureHandles.channel(chan).histAx,im(:), 50); %Update histogram data
	
		%Make the histogram red
		c=get([obj.figureHandles.channel(chan).histAx],'Children');
		set(c, ...
			'EdgeColor','None', ...
			'FaceColor','c',...
			'FaceAlpha',0.75)

	end

	%Keep the axes of the histogram looking nice
    maxVal=obj.AIrange;
	set([obj.figureHandles.channel(:).histAx], ...
		'YTick', [], ...
		'XLim', [-0.05,maxVal], ... 
		'Color', 'None', ...
		'Box', 'Off');


	set([obj.figureHandles.channel(:).imAx], ...
		'XLim', [1,size(obj.imageDataFromLastFrame,2)],...
        'CLim',[0,maxVal]);


end %plotLastFrameData
