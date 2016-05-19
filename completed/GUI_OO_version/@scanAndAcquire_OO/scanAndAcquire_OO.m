classdef  scanAndAcquire_OO < handle

	% Simple class for acquiring data with a 2-photon microscope
	%
	% Details
	% The X mirror should be on AO-0
	% The Y mirror should be on AO-1
	% No Pockels blanking and all the waveform is used.
	%
	% Inputs (required)
	% hardwareDeviceID - string defining the ID of the DAQ device 
	%					 see daq.getDevices for finding the ID of your device.
	%
	% Inputs (optional, supplied as param/value pairs)
	% 'inputChans' - A vector defining which input channels will be used to acquire data 
	%  				[0 by default, meaning channel 0 only is used to acquire data]
	% 'saveFname'  - A string defining the relative or absolute path of a file to which data should be written. 
	%                Data will be written as a TIFF stack. If not supplied, no data are saved to disk. 
	%				 NOTE: if a TIFF  with this name already exists, data will be appended to it.
	% 'amplitude'  - The amplitude of the voltage waveform. [2 by default, meaning +/- 2V]
	% 'imSize'  - The number of pixels in x/y. Square frames only are produced. [256 by default.]
	% 'sampleRate' - The samples/second for the DAQ to run. [256E3 by default]
	% 'fillFraction' 	 - The proportion of the scan range to keep. 1-fillFraction 
	%	    			   is discarded due to the scanner turn-around. [0.9 by default]
	% 'samplesPerPixel'  - Number of samples per pixel. [4 by default]
	% 'scanPattern'  - A string defining whether we do uni or bidirectional scanning: 'uni' or 'bidi'
	%				 'uni' by default
	% 'bidiPhase' - a scalar that defines the offset in pixels between the outgoing and return lines
	% 			    in bidirectional scanning. 26 by default. This parameter needs changing often and is sensitive.
	% 'enableHist'   - A boolean. True by default. If true, overlays an intensity histogram on top of the image.
	%
	%
	% Examples
	% ONE
	% The following example shows how to list the available DAQ devices, then create an
	% instance of the object and start and stop scanning.
	%
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
	% >> S = scanAndAcquire_OO('Dev1');
	% >> S.prepareQueueAndBuffer
	% % Acquire 10 seconds of data
	% >> S.startScan; pause(10); S.stopScan
	% >> delete(S) %close down the session
	%
	%
	%
	% Rob Campbell - Basel 2015


	properties

		%Properties that hold handles to important objects
		deviceID  % String holding the device ID of the DAQ board

		%Default settings that can be over-ridden by the user
		inputChans = 0
		sampleRate = 512E3
		samplesPerPixel = 4
		imSize = 256 		
		scannerAmplitude = 2
		fillFraction = 0.9
		scanPattern = 'uni'
		bidiPhase = 26
		saveFname =  ''

		%Data from the last frame are stored here:
		imageDataFromLastFrame %an array of size: imageRows x imageCols x numChannels
	end


	properties (Hidden)

		%Properties that hold handles to important objects
		hDAQ  	  % The DAQ device object 
		hAI 	  % Analog input channels
		numFrames % Counter for number of frames acquired 
		startTime % Serial date at start of scan
		getDataListener 		% Listener that pulls in data off the DAQ after each frame
		queueWaveformsListener 	% Listern that sends galvo waveform data to DAQ buffer
		figureHandles % Keep figure handles here (for now) TODO

		% A structure populated by prepareQueueAndBuffer
		scanQueue = struct('galvoWaveformData', [], ...
							'numFramesInQueue', [], ...
							'pointsPerLine', [])

		%Settings that are unlikely to need changing
		AI_range = 2 			% Digitise over +/- this range
		scannerChannels = 0:1	% These are the AO channels to which the scanners are connected [x,y]
		sessionType = 'ni' 		% We will work with NI hardware
		measurementType = 'Voltage' % We will acquire voltage data 
		maxScannerVoltage = 10 
		minSecondsOfBufferedData = 0.25 %Each time fill the output buffer with at least this many seconds of data to avoid buffer under-runs
	end


	methods

		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		%CONSTRUCTOR
		function obj = scanAndAcquire_OO(hardwareDeviceID,varargin)
			if ~ischar(hardwareDeviceID)
				fprintf('hardwareDeviceID should be a string\n')
				return
			end
			obj.deviceID=hardwareDeviceID;

			params = inputParser;
			params.CaseSensitive = false;
			params.addParameter('inputChans',	 	obj.inputChans,		@(x) isnumeric(x));
			params.addParameter('saveFname',		obj.saveFname,		@(x) ischar(x));
			params.addParameter('imSize', 			obj.imSize,			@(x) isnumeric(x) && isscalar(x));
			params.addParameter('samplesPerPixel', 	obj.samplesPerPixel,@(x) isnumeric(x) && isscalar(x));
			params.addParameter('sampleRate',		obj.sampleRate,		@(x) isnumeric(x) && isscalar(x));
			params.addParameter('fillFraction', 	obj.fillFraction,	@(x) isnumeric(x) && isscalar(x));
			params.addParameter('scanPattern',		obj.scanPattern,	@(x) ischar(x));
			params.addParameter('bidiPhase', 		obj.bidiPhase,		@(x) isnumeric(x) && isscalar(x));
			params.addParameter('scannerAmplitude', obj.scannerAmplitude, @(x) isnumeric(x) && isscalar(x));

			%Process the input arguments in varargin using the inputParser object we just built
			params.parse(varargin{:});

			%Extract values from the inputParser
			obj.inputChans		= params.Results.inputChans;
			obj.saveFname 		=  params.Results.saveFname;
			obj.imSize 			= params.Results.imSize;
			obj.samplesPerPixel = params.Results.samplesPerPixel;
			obj.sampleRate 		= params.Results.sampleRate;
			obj.fillFraction 	= params.Results.fillFraction;
			obj.scanPattern 	= params.Results.scanPattern;
			obj.bidiPhase 		= params.Results.bidiPhase;
			obj.scannerAmplitude = params.Results.scannerAmplitude;

			if ~obj.checkScanParams
				fprintf('\n PLEASE CHECK YOUR SCANNER SETTINGS then run connectToDAQ\n\n')
				return
			end

			obj.connectToDAQ

		end %close constructor



		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		%DESTRUCTOR
		function delete(obj)
			obj.stopAndDisconnectDAQ(false); %stop and don't report the number of acquired frames
			delete(obj.getDataListener)
			delete(obj.queueWaveformsListener)
		end %close destructor




		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		% Short methods follow. Longer ones in standalone .m files
		function startScan(obj)
			obj.prepareQueueAndBuffer %TODO: test if data have been queued or just run this each time?
			obj.startTime=now;
			obj.numFrames=0;
			obj.setUpFigureWindow %TODO: plotting should possibly be done via a procedural GUI and a notifier
			obj.hDAQ.startBackground %start the acquisition in the background
		end %close startScan

		function stopScan(obj,reportFramesAcquired)
			if nargin<2
				reportFramesAcquired=true;
			end

			obj.hDAQ.stop; 

			if reportFramesAcquired
				if obj.numFrames==0
					fprintf('\nSomething went wrong. No frames were acquired.\n')
				else
					fprintf('Acquired %d frames in %0.1f\n', obj.numFrames, (now-obj.startTime)*60^2*24)
				end
			end

		end %close stop

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


		function varargout = fps(obj)
			% Returns the number of frames per second.
			% If called with an output argument, the value is returned
			% and nothing is printed to screen. 
			if isempty(obj.hDAQ)
				fprintf('Please connect the DAQ device\n')
				return
			end
			if isempty(obj.scanQueue.galvoWaveformData)
				fprintf('No queue has been set up. Please run the prepareQueueAndBuffer method.\n')
				return
			end

			fps = obj.hDAQ.Rate/length(obj.scanQueue.galvoWaveformData);
			fps = fps * obj.scanQueue.numFramesInQueue;

			if nargout==0
				fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n', ...
					obj.imSize, obj.imSize, fps)
			else
				varargout{1}=fps;
			end
		end %close fps

		function scanSettings(obj)
			%Show the scan settings to screen
			if isempty(obj.hDAQ)
				fprintf('Please connect the DAQ device\n')
				return
			end
			if isempty(obj.scanQueue.galvoWaveformData)
				fprintf('No queue has been set up\n')
				return
			end
			
			msOfDataInQueue = round( (length(obj.scanQueue.galvoWaveformData)/obj.hDAQ.Rate)*1000 );
			fprintf('There is %d ms of data in the output queue ',msOfDataInQueue)
			if obj.scanQueue.numFramesInQueue>1
				fprintf('(queuing in blocks of %d frames)',obj.scanQueue.numFramesInQueue)
			end
			fprintf('\n')

			obj.fps
		end %close scanSettings

	end %close methods

	methods (Hidden)
		function frame = buildImageFromOneChannel(obj,imData,channelID)
			% Construct a square image from column "channelID" in the 
			% nSamples-by-cChannels array, imData, that has come off the 
			% acquisition card. Turn-around artifact removed.

			%Average all points from the same pixel
			frame = imData(:,channelID);
			frame = mean(reshape(imData,[],obj.samplesPerPixel),2); 

			%Create a square image of the correct orientation
			frame = reshape(frame, [], obj.imSize); 
			frame = -rot90(frame);


			%Remove the turn-around artefact 
			if strcmpi(obj.scanPattern,'bidi')
				%Flip the even rows if data were acquired bidirectionally
				frame(2:2:end,:) = fliplr(frame(2:2:end,:));

				frame(1:2:end,:) = circshift(frame(1:2:end,:),-obj.bidiPhase,2);
				frame(2:2:end,:) = circshift(frame(2:2:end,:), obj.bidiPhase,2);

				frame = fliplr(frame); %To keep it in the same orientation as the uni-directional scan
				frame = frame(:,1+obj.bidiPhase:end-obj.bidiPhase); %Trim the turnaround on one edge (BADLY)
			else
				frame = frame(:,end-obj.imSize+1:end); %Trim the turnaround on one edge
			end

		end %close buildImageFromOneChannel

	end %close hidden methods

end %close scanAndAcquire_OO


