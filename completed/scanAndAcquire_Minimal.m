function scanAndAcquire_Minimal(DeviceID)
% Minimal code needed to acquire data from one channel of a 2-photon microscope
%
% function scanAndAcquire_Minimal(DeviceID)
%
% Purpose
% Stripped down code containing the minimum necessary to get data out of a 2p microscope
% All parameters are hard-coded within the function to keep code short and focus on the 
% DAQ stuff. No Pockels blanking, all the waveform is used, etc.
%
%
% Instructions
% Simply call the function with device ID of your NI acquisition board. 
% Quit with ctrl-C.
%
%
% Inputs
% hardwareDeviceID - a string defining the device ID of your NI acquisition boad. Use the command
%                    "daq.getDevices" to find the ID of your board.
%
%
% Example
% The following example shows how to list the available DAQ devices and start
% scanAndAcquire_Polished using the ID for the NI PCI-6115 card with the default. 
% scanning options. 
%
% >> daq.getDevices
%
% ans = 
%
% Data acquisition devices:
%
% index Vendor Device ID          Description          
% ----- ------ --------- ------------------------------
% 1     ni     Dev1      National Instruments PCI-6115
% 2     ni     Dev2      National Instruments PCIe-6321
% 3     ni     Dev3      National Instruments PCI-6229
%
% >> scanAndAcquire_Minimal('Dev1')
% 
%
%
% Rob Campbell - Basel 2015


	% Scan parameters
	galvoAmp   = 2 ;     % Galvo amplitude (actually, this is amplitude/2). Increasing this increases the area scanned (CAREFUL!)
	imSize     = 256 ;   % Number of pixel rows and columns. Increasing this value will decrease the frame rate and increase the resolution.
	sampleRate = 128E3 ; % Increasing the sampling rate will increase the frame rate (CAREFUL!)
	AI_range = 2; % Digitise over +/- this range. This is a setting we are unlikely to change often

	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE
	s=daq.createSession('ni'); %Create a session using NI hardware
	s.Rate = sampleRate;  % The sample rate is fixed, so changing it will alter the frame rate

	%Define a cleanup object that will release the DAQ gracefully when the user presses ctrl-c
	tidyUp = onCleanup(@() stopAcq(s));

	AI=s.addAnalogInputChannel(DeviceID, 'ai1', 'Voltage');	%Add an analog input channel for the PMT signal
	AI.Range = [-AI_range,AI_range];

	addlistener(s,'DataAvailable', @plotData); 	% Add a listener to get data back from this channel
	s.addAnalogOutputChannel(DeviceID,0:1,'Voltage'); % Add analog two output channels for scanners:  0 is x and 1 is y


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS
	yWaveform = linspace(galvoAmp,-galvoAmp,imSize^2); % Y waveform is:

	xWaveform = linspace(-galvoAmp, galvoAmp, imSize); % One line of X
	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform)); % All the X lines

	dataToPlay = [xWaveform(:),yWaveform(:)]; %Assemble the two waveforms into an N-by-2 array


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE
	fps = (sampleRate/size(dataToPlay,2))/length(dataToPlay);
	fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n',imSize,imSize,fps)

	%The output buffer is re-filled for the next line when it becomes half empty
	s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 

	%This listener tops up the output buffer
	addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

	s.IsContinuous = true; %needed to provide continuous behavior
	s.queueOutputData(dataToPlay); %queue the first frame
	
	s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %Pull in the data when the frame has been acquired


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA
	clf
	hIm=imagesc(zeros(imSize)); %keep a handle to the image plot object
	imAx=gca;
	colormap gray
	set(imAx,'XTick',[], 'YTick',[], 'Position',[0,0,1,1])


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	s.startBackground %start the acquisition in the background
	while 1 %Block. User presses ctrl-C to to quit, this calls stopAcq
		pause(0.1)
	end



	function plotData(src,event)
		%This function is called every time a frame is acquired
		x=event.Data;

		if length(x)<=1
			return
		end
		im = reshape(x,imSize,imSize);
		im = rot90(im); %So the fast axis (x) is show along the image rows
		im = -im; %because the data are negative-going

		set(hIm,'CData',im);
		set(imAx,'CLim',[0,AI_range]);
 	end %plotData


end %scanAndAcquire




%-----------------------------------------------
function stopAcq(s)
	% This function is called when the user presses ctrl-C or if the acquisition crashes
	s.stop; % Stop the acquisition

	% Zero the scanners
	s.IsContinuous=false; %
	s.queueOutputData([0,0]); %Queue zero volts on each channel
	s.startForeground; % Set analog outputs to zero

	release(s);	% Release control of the board
end %stopAcq
