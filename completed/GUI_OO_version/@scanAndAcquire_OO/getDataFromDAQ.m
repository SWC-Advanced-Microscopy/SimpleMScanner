function getDataFromDAQ(obj,event)
	% This is the callback for the listener "getDataListener"
	% It runs after each frame has been acquired.
	% It populates the property	imageDataFromLastFrame

	imData=event.Data;

	if size(imData,1)<=1
		return
	end

	%Build square images for all channels 
	obj.imageDataFromLastFrame = obj.buildImageFromOneChannel(imData,1);
	if length(obj.inputChans)>1
		obj.imageDataFromLastFrame = repmat(obj.imageDataFromLastFrame,[1,1,length(obj.inputChans)]);
		for ii=2:length(obj.inputChans)
			obj.imageDataFromLastFrame(:,:,ii) = obj.buildImageFromOneChannel(imData,ii);
		end
	end

	obj.numFrames = obj.numFrames+1; %increment the frame counter

	%TODO: the following should possibly not be here, or be elsewhere. 
	obj.saveLastFrameToDisk
	obj.plotLastFrameData

end %close getDataFromDAQ
