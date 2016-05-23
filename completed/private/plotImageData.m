function plotImageData(imData,h,saveFname,bidiPhaseDelay)
	%Plot (and optionally save) data produced by scanAndAcquire_Polished
	%
	% function plotImageData(imData,h,saveFname,scanPattern)
	%
	% Purpose
	% This function is called once each frame has been acquired.
	% It plots one or more channels of data to screen and also optionally
	% saves data to disk. This function is called by scanAndAcquire_Polished.
	%
	% 
	% Inputs
	% imData - Data pulled in from NI board after one frame then downsampled such that each row
	%          represents a data point from a different pixel. Columns are channels.
	% h - plot handles structure produced by scanAndAcquire_Polished
	% saveFname - [string] the relative or absolute path of a file to which data should be saved. 
	%             If empty, no data are saved.
	% bidiPhaseDelay - [optional] If missing or empty, we assume the images are acquired using a uni-directional
	%                  scan pattern. If bidiPhaseDelay is present, it is a scalar used to correct the phase
	% 			       offset between the outgoing and return scanlines.
	%
	%
	% Rob Campbell - Basel 2016

	if nargin<4
		bidiPhaseDelay=[];
	end

	imSize = size(get(h(1).hAx,'CData'),1);

	timeStamp = now*60^2*24*1E3; %MATLAB serial date in ms. This is used for saving. 

	%The analog input range is in the CLIM property of the image axes
	AI_range = get(h(1).imAx,'CLim');
	AI_range = AI_range(2);

	for chan = 1:size(imData,2)
		
		im = reshape(imData(:,chan), [], imSize);
		im = -rot90(im);

		%Remove the turn-around artefact 
		if ~isempty(bidiPhaseDelay)
			%Flip the even rows if data were acquired bidirectionally
			im(2:2:end,:) = fliplr(im(2:2:end,:));

			im(1:2:end,:) = circshift(im(1:2:end,:),-bidiPhaseDelay,2);
			im(2:2:end,:) = circshift(im(2:2:end,:), bidiPhaseDelay,2);

			im = fliplr(im); %To keep it in the same orientation as the uni-directional scan

			im = im(:,1+bidiPhaseDelay:end-bidiPhaseDelay); %Trim the turnaround on one edge (BADLY)
			set(h(chan).imAx,'XLim',[1,size(im,2)]);
		else
			im = im(:,end-imSize+1:end); %Trim the turnaround on one edge
		end

		%Update image
		set(h(chan).hAx,'CData',im);



		if h(chan).histAx ~= 0
			%Update histogram data
			hist(h(chan).histAx,im(:),50);

			%Keep the axes of the histogram looking nice
			set(h(chan).histAx, ...
				'YTick', [], ...
				'XLim', [-0.1,AI_range], ... 
				'Color', 'None', ...
				'Box', 'Off');


			%Make the histogram red
			c=get(h(chan).histAx,'Children');
			set(c, ...
				'EdgeColor','None', ...
				'FaceColor','r',...
				'FaceAlpha',0.75)
		end

		% - - - - - - - - - - - - - - - - - -  
		%Optionally write data to disk
		if ~isempty(saveFname) 
			if length(h)>1
				thisFname = [h(chan).hAx.tag,saveFname];
			else
				thisFname = saveFname;
			end
			im = im * 2^16/AI_range ; %ensure values span 16 bit range

			imwrite(uint16(im), thisFname, 'tiff', ...
						'Compression', 'None', ... 
	    				'WriteMode', 'Append',....
	    				'Description',sprintf('%f',timeStamp));
		end
		% - - - - - - - - - - - - - - - - - -  



	end
