function plotImageData(imData,h,saveFname,scanPattern)
	%Plot (and optionally save) data produced by scanAndAcquire_Polished
	%
	% function plotImageData(imData,h,saveFname,scanPattern)
	%
	% Purpose
	% This function is called once each frame has been acquired.
	% It plots one or more channels of data to screen and also optionally
	% saves data to disk. 
	%
	% 
	% Inputs
	% imData - Data pulled in from NI board after one frame then downsampled such that each row
	%          represents a data point from a different pixel. Columns are channels.
	% h - plot handles structure produced by scanAndAcquire_Polished
	% saveFname - [string] the relative or absolute path of a file to which data should be saved. 
	%             If empty, no data are saved.
	% scanPattern - [string] Either 'uni' or 'bidi' depending on the scan pattern used.
	%
	%
	% Rob Campbell - Basel 2016


	imSize = size(get(h(1).hAx,'CData'),1);

	%The number of points on one line (larger then imSize if fillFraction < 1)
	pointsPerLine = size(imData,1) / imSize; 


	for chan = 1:size(xData,2)
		
		im = reshape(imData(:,chan), pointsPerLine, imSize);
		im = -rot90(im);

		%Remove the turn-around artefact 
		switch lower(scanPattern)
			case 'bidi'
				%Flip the even rows if data were acquired bidirectionally
				im(2:2:end,:) = fliplr(im(2:2:end,:));
				startIndex = ceil((size(im,1)-imSize)/2);
				im = im(:,startIndex:startIndex+imSize); %Trim the turnarounds on both edges
			case 'uni'
				im = im(:,end-imSize:end); %Trim the turnaround on one edge
		end



		%Update histogram on this frame
		hist(h(chan).histAx,im(:),30);

		set(h(chan).histAx, ...
			'YTick', [], ...
			'XLim', [-0.1,2], ...
			'Color', 'None', ...
			'Box', 'Off');


		%Make the histogram red
		c=get(h.(chan),'Children');
		set(c, ...
			'EdgeColor','None', ...
			'FaceColor','r')


		%Update image on this frame
		set(h(chan).hAx,'CData',im);
		set(h(chan).imAx,'CLim',[0,2]);



		if ~isempty(saveFname) %Optionally write data to disk
			if length(inputChans)>1
				thisFname = sprintf('ch%02d_%s',inputChans(chan),saveFname);
			else
				thisFname = saveFname;
			end
			im = im * 2^16/AI_range ; %ensure values span 16 bit range
			imwrite(uint16(im), thisFname, 'tiff', ...
						'Compression', 'None', ... 
	    				'WriteMode', 'Append');
		end

	end
