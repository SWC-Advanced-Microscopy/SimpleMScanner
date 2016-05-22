function connectToDAQ(obj,deviceID)
	% Connect to the NI DAQ device and perform all set up functions that 
	% do not involve the galvo waveforms. Thus, this method can be called 
	% once only to set up the session. 


	if nargin>1 %Just in case we want to call this function separately
		obj.deviceID=deviceID;
	end

	if ~isempty(obj.hDAQ)
		fprintf('DAQ device already connected\n')
		return
	end

	if ~obj.checkScanParams
		fprintf('\n PLEASE CHECK YOUR SCANNER SETTINGS then re-run connectToDAQ\n\n')
		return
	end

	%Create a DAQ session
	obj.hDAQ = daq.createSession(obj.sessionType);
	obj.sampleRate = obj.sampleRate; %Calls the setter


	%Add one or more analog input channels for the PMT signals and sets the analog input range
	obj.inputChans = obj.inputChans; %Runs the setter in scanAndAcquire_OO


	%Add a listener to get data back after each frame
	obj.getDataListener = addlistener(obj.hDAQ, 'DataAvailable', @(src,event) obj.getDataFromDAQ(event)); 

	%Add analog two output channels for scanners 0 is x and 1 is y
	obj.hDAQ.addAnalogOutputChannel(obj.deviceID, obj.scannerChannels, obj.measurementType); 

end %close connectToDAQ
