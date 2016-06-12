function saveLastFrameToDisk(obj)
	% Plots data from the last frame

	if isempty(obj.saveFname) 
		%TODO: better checks. e.g. can we save?
		return
	end

	for chan = 1:size(obj.imageDataFromLastFrame,3)

		im = obj.imageDataFromLastFrame(:,:,chan);

		if length(obj.figureHandles.channel)>1
			thisFname = sprintf('%s_chan%02d', obj.saveFname, obj.inputChans(chan));
		else
			thisFname = obj.saveFname;
		end

		im = im * 2^16/obj.AIrange; %ensure values span 16 bit range
		imwrite(uint16(im), thisFname, 'tiff', ...
				'Compression', 'None', ... 
   				'WriteMode', 'Append',....
   				'Description',sprintf('%f',obj.lastFrameEndTime));
	end

end %saveLastFrameToDisk
