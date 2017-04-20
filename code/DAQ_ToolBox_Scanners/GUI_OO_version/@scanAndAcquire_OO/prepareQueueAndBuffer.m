function prepareQueueAndBuffer(obj,verbose) 
	% Prepare to scan and acquire data
	%
	% function prepareDAQforScan(obj,verbose) 
	% 
	%
	% Purpose
	% This method is called before starting the acquisition. It builds
	% the waveform data, buffers it, and sets up the DAQ for continuous
	% acquisition. It fills the scanQueue property with a structure that 
	% describes the scan settings.
	%


	if nargin<2
		verbose=false;
	end

	% Build one frame's worth of scan waveforms
	obj.scanQueue.galvoWaveformData = obj.galvoWaveforms(verbose);

	% Determine how many frames we need in order to have at least minSecondsOfBufferedData seconds
	% of data added to the queue each time.
	secondsOfDataToBeQueued = length(obj.scanQueue.galvoWaveformData)/obj.hDAQ.Rate;
	obj.scanQueue.numFramesInQueue = ceil(obj.minSecondsOfBufferedData / secondsOfDataToBeQueued);

	%expand queued data accordingly
	obj.scanQueue.galvoWaveformData = repmat(obj.scanQueue.galvoWaveformData, obj.scanQueue.numFramesInQueue, 1); 
  

	%The output buffer is re-filled when it becomes half empty
	obj.hDAQ.NotifyWhenScansQueuedBelow = round(length(obj.scanQueue.galvoWaveformData)*0.5); 

	%This listener tops up the output buffer
	obj.queueWaveformsListener = addlistener(obj.hDAQ,'DataRequired', ...
		@(src,event) src.queueOutputData(obj.scanQueue.galvoWaveformData));

	obj.hDAQ.IsContinuous = true; %needed to provide continuous behavior
	obj.hDAQ.queueOutputData(obj.scanQueue.galvoWaveformData); %queue the first frame

	%Pull in the data when each frame has been acquired (this is when to trigger queueWaveformsListener)
	obj.hDAQ.NotifyWhenDataAvailableExceeds = length(obj.scanQueue.galvoWaveformData) / obj.scanQueue.numFramesInQueue; 

end %close prepareDAQforScan
