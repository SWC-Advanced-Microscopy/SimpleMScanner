
function plotLastFrameData(obj)
	% Plots data from the last frame
	%
	% TODO: Might want to remove the plotting from the class

	for chan = 1:size(obj.imageDataFromLastFrame,3)
		im = obj.imageDataFromLastFrame(:,:,chan);
		set(obj.figureHandles.channel(chan).hAx, 'CData', im) %Update image
		hist(obj.figureHandles.channel(chan).histAx,im(:), 50); %Update histogram data
	end

	%Keep the axes of the histogram looking nice
	set([obj.figureHandles.channel(:).histAx], ...
		'YTick', [], ...
		'XLim', [-0.1,obj.AI_range], ... 
		'Color', 'None', ...
		'Box', 'Off');

	%Make the histogram red
	c=get([obj.figureHandles.channel(:).histAx],'Children');
	set(c, ...
		'EdgeColor','None', ...
		'FaceColor','r',...
		'FaceAlpha',0.75)

	if strcmpi(obj.scanPattern,'bidi')
		%Because we are trimming X in a nasty way
		set([obj.figureHandles.channel(:).imAx],'XLim',[1,size(obj.imageDataFromLastFrame,2)]);
	end

end %plotLastFrameData
