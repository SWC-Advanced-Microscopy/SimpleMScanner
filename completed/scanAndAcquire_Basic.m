function scanAndAcquire_Basic(hardwareDeviceID,saveFname)
% Basic useful 2-photon microscope acquisition for one channel: acquires nice images that can be saved to disk
%
% function scanAndAcquire_Basic(hardwareDeviceID)
%
%
% Purpose
% Acquires a 2-photon image stream from channel 1 of a DAQ card. All parameters are hard-coded within 
% the function to keep code short and focus on the DAQ stuff. This function is based on 
% scanAndAcquire_Minimal but adds the following:
%  1) Correction of the X-mirror turn-around artefact
%  2) Ability to acquire multiple samples per pixel to decrease noise
%  3) Optionally save the image stream to disk
%
% No Pockels blanking.
%
%
% Instructions
% Simply call the function with device ID of your NI acquisition board. 
% Quit by closing the window showing the scanned image stream.
%
%
% Inputs
% hardwareDeviceID - a string defining the device ID of your NI acquisition boad. Use the command
%                    "daq.getDevices" to find the ID of your board.
% saveFname - A string defining the relative or absolute path of a file to which data should be written. 
%             Data will be written as a TIFF stack. If not supplied, no data are saved to disk. 
%
%
% Instructions
% Simply call the function. To stop scanning, close the figure window.
%
%
% Examples
% ONE
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
% >> scanAndAcquire_Basic('Dev1')
% 
% TWO
% Save data to a file called '2pStream.tif'
% >> scanAndAcquire_Basic('Dev1','2pStream.tif')
% 
% 
% Rob Campbell - Basel 2015


	if ~ischar(hardwareDeviceID)
		fprintf('hardwareDeviceID should be a string\n')
		return
	end

	if nargin<2
		saveFname='';
	end

	if ~ischar(saveFname)
		fprintf('The input argument saveFname should be a string. Not saving data to disk.\n')
		saveFname='';
	end

	if ~isempty(saveFname)
		tiffWriteParams={saveFname, 'tiff',   ...
						'Compression', 'None', ... %Don't compress because this slows IO
	    				'WriteMode', 'Append'};
	end



	%----------------------------------
	% Scan parameters
	galvoAmp = 2; %Scanner amplitude (actually, this is amplitude/2)
	imSize = 256; %Number pixel rows and columns
	samplesPerPixel = 4;
	sampleRate 	= 512E3; 
	fillFraction = 0.9; %1-fillFraction is considered to be the turn-around time and is excluded from the image
	AI_range = 2; % Digitise over +/- this range. This is a setting we are unlikely to change often
	%----------------------------------


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE

	%Create a session using NI hardware
	s=daq.createSession('ni');
	s.Rate = sampleRate;

	%Add an analog input channel for the PMT signal
	AI=s.addAnalogInputChannel(hardwareDeviceID, 'ai0', 'Voltage');
	AI.Range = [-AI_range,AI_range];

	%Add analog two output channels for scanners 0 is x and 1 is y
	s.addAnalogOutputChannel(hardwareDeviceID,0:1,'Voltage');





	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS

	% Calculate the number of samples per line. We want to produce a final image composed of
	% "imSize" data points on each line. However, if the fill fraction is less than 1, we
	% need to collect more than this then trim it back. TODO: explain fillfraction
	fillFractionExcess = 2-fillFraction; %The proprotional increase in scanned area along X
	correctedPointsPerLine = ceil(imSize*fillFractionExcess); %collect more points
	samplesPerLine = correctedPointsPerLine*samplesPerPixel;

	%So the Y waveform is:
	yWaveform = linspace(galvoAmp,-galvoAmp,samplesPerLine*imSize);

	% Produce the X waveform
	xWaveform = linspace(-galvoAmp, galvoAmp, samplesPerLine); 
	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));

	%Assemble the two waveforms into an N-by-2 array
	dataToPlay = [xWaveform(:),yWaveform(:)];
	fprintf('Data waveforms have length %d\n',size(dataToPlay,1))
	



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE

	%The sample rate is fixed, so we report the frame rate
	fps = sampleRate/length(dataToPlay);
	fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n',imSize,imSize,fps)

	%The output buffer is re-filled when it becomes half empty
	s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 

	%This listener tops up the output buffer
	addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

	s.IsContinuous = true; %needed to provide continuous behavior
	s.queueOutputData(dataToPlay); %queue the first frame

	%Pull in the data when the frame has been acquired
	addlistener(s,'DataAvailable', @plotData); 	%Add a listener to get data back from this channel
	s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %when to read back




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA

	%We will plot the data on screen as they come in, so make a blank image
	hFig=clf;
	hIm=imagesc(zeros(imSize));
	imAx=gca;
	colormap gray
	set(imAx, 'XTick',[], 'YTick',[], 'Position',[0,0,1,1]) %Fill the window
	axis square



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	set(hFig,'CloseRequestFcn', @(~,~) figCloseAndStopScan(s,hFig));
	s.startBackground %start the acquisition in the background
	fprintf('Close window to stop scanning\n')



	function plotData(src,event)
		%This function is called every time a frame is acquired
		x=event.Data;

		if length(x)<=1
			return
		end
		x = mean(reshape(x,samplesPerPixel,[]),1)'; %Average all points from the same pixel
		im = reshape(x,correctedPointsPerLine,imSize);
		im = im(end-imSize:end,:); %trim according to the fill-fraction to remove the turn-around 
		im = rot90(im); %So the fast axis (x) is show along the image rows
		im = -im; %because the data are negative-going

		set(hIm,'CData',im);
		set(imAx,'CLim',[0,AI_range]);
		if ~isempty(saveFname) %Optionally write data to disk
			im = im * 2^16/AI_range ; %ensure values span 16 bit range
			imwrite(uint16(im),tiffWriteParams{:}) %This will wipe the negative numbers (the noise)
		end

 	end %plotData

end %scanAndAcquire



%-----------------------------------------------

function figCloseAndStopScan(s,hFig)
	%Runs on scan figure window close
	delete(hFig)
	stopAcq(s)
	
end

function stopAcq(s)
	fprintf('Shutting down DAQ connection and zeroing scanners\n')
	s.stop; % Stop the acquisition

	% Zero the scanners
	s.IsContinuous=false; %
	s.queueOutputData([0,0]); %Queue zero volts on each channel
	s.startForeground; % Set analog outputs to zero

	release(s);	% Release control of the board
end %stopAcq
