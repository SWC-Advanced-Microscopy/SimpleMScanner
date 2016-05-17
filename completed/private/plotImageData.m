function plotImageData(xData,histAx,hAx,imAx,tiffWriteParams)


		for chan = 1:size(xData,2)
			x=xData(:,chan);
			x=decimate(x,samplesPerPoint);

			if correctedPointsPerLine * linesPerFrame ~= size(x,1)
				fprintf('Can not reshape vector of length %d to a %d by %d matrix\n',size(x,1), correctedPointsPerLine, linesPerFrame)
				return
			end
			im = reshape(x,correctedPointsPerLine,linesPerFrame);
			im = im(end-pointsPerLine:end,:); %trim TODO: modify for bidi scanning
			im = rot90(im);
			im = -im; %because the data are negative-going

			%Update histogram on this frame
			hist(histAx(chan),im(:),30);
			set(histAx(chan),'YTick',[], 'XLim',[-0.1,2], 'Color','None', 'Box','Off');
			set(get(histAx(chan),'Children'),'EdgeColor','None','FaceColor','r')


			%Update image on this frame
			set(hAx(chan),'CData',im);
			set(imAx(chan),'CLim',[0,2]);

			if ~isempty(saveFname) %Optionally write data to disk
				if length(inputChans)>1
					thisFname = sprintf('ch%02d_%s',inputChans(chan),saveFname);
				else
					thisFname = saveFname;
				end
				im = im * 2^16/AI_range ; %ensure values span 16 bit range
				imwrite(uint16(im),thisFname,tiffWriteParams{:}) %This will wipe the negative numbers (the noise)
			end
		end