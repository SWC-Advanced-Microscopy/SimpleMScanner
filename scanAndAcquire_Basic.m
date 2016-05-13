function scanAndAcquire
% Produce simple scan waveforms for X/Y galvos and acquire data from one PMT channel using uni-directional scanning
%
% All parameters are hard-coded within the function to keep code short and focus
% on the DAQ stuff.
%
% No Pockels blanking and all the waveform is used.
%
%
% Instructions
% Simply call the function. Quit with ctrl-C.
%
%
% Rob Campbell - Basel 2015


	%Define a cleanup object that will release the DAQ gracefully
	tidyUp = onCleanup(@stopAcq);


	%----------------------------------
	%User settings
	amp=2; %Scanner amplitude
	linesPerFrame = 256;
	pointsPerLine = 256;
	samplesPerPoint = 4;
	sampleRate 	= 512E3; 
	fillFraction = 0.9; %1-fillFraction is considered to be the turn-around time and is excluded from the image
	%----------------------------------


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE

	%Create a session using NI hardware
	s=daq.createSession('ni');


	%Add an analog input channel for the PMT signal
	AI=s.addAnalogInputChannel('Dev1', 'ai1', 'Voltage'); %Hard-coded. This is a PCI 6115
	AI.Range = [-2,2];


	%Add a listener to get data back from this channel
	addlistener(s,'DataAvailable', @plotData); 


	%Add analog two output channels for scanners 0 is x and 1 is y
	s.addAnalogOutputChannel('Dev1',0:1,'Voltage'); %the 6115 is assigned to Dev1





	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS

	% Calculate the number of samples per line. We want to produce a final image composed of
	% pointsPerLine data points on each line. However, if the fill fraction is less than 1, we
	% need to collect more than this then trim it back. 
	correctedPointsPerLine = ceil(pointsPerLine*(2-fillFraction)); %collect more points
	samplesPerLine = correctedPointsPerLine*samplesPerPoint;

	%So the Y waveform is:
	yWaveform = linspace(amp,-amp,samplesPerLine*linesPerFrame);

	%Produce the X waveform
	xWaveform = linspace(-amp, amp, samplesPerLine);
	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));

	%Assemble the two waveforms into an N-by-2 array
	dataToPlay = [xWaveform(:),yWaveform(:)];
	fprintf('Data waveforms have length %d\n',size(dataToPlay,1))
	



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE

	%The sample rate is fixed, so we report the frame rate
	s.Rate = sampleRate;
	frameRate = length(yWaveform)/sampleRate;
	fprintf('Scanning at %0.2f frames per second\n',1/frameRate)

	%The output buffer is re-filled for the next line when it becomes half empty
	s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 

	%This listener tops up the output buffer
	addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

	s.IsContinuous = true; %needed to provide continuous behavior
	s.queueOutputData(dataToPlay); %queue the first frame

	%Pull in the data when the frame has been acquired
	s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %when to read back




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA

	%We will plot the data on screen as they come in, so make a blank image
	hFig=clf;
	histAx=subplot(1,2,1);

	imAx=subplot(1,2,2);
	hAx=imagesc(zeros(linesPerFrame,pointsPerLine));
	colormap gray




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	s.startBackground %start the acquisition in the background

	%Block. User presses ctrl-C to to quit, this calls stopAcq
	while 1,pause(0.1), end


	%-----------------------------------------------
	function stopAcq
		fprintf('Zeroing AO channels\n')
		s.stop;
		s.IsContinuous=false;
		s.queueOutputData([0,0]);
		s.startForeground;

		fprintf('Releasing NI hardware\n')
		release(s);
	end %stopAcq


	function plotData(src,event)
		x=event.Data;

		if length(x)<=1
			fprintf('No data\n')
			return
		end

		x=decimate(x,samplesPerPoint);
		im=reshape(x,correctedPointsPerLine,linesPerFrame);
		im=im(end-pointsPerLine:end,:); %trim
		im=rot90(im);
		im=im*-1; %because the data are negative-going

		hist(histAx,im(:),100);
		set(histAx,'xlim',[-0.1,2])

		R=[min(im(:)), max(im(:))];
		set(hAx,'CData',im);
		set(imAx,'CLim',[0,2]);
		
 	end %plotData

end %scanAndAcquire