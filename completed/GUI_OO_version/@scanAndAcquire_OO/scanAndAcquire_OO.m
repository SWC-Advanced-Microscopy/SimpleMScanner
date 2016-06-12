classdef  scanAndAcquire_OO < handle

    % Simple class for acquiring data with a 2-photon microscope
    %
    % scanAndAcquire_OO(paramFile)
    %
    %
    % * Purpose
    % scanAndAcquire_OO is an object-oriented version of scanAndAcquire_Polished.
    % This function controls scanning and image acquisition of a scanning microscope, such as
    % a 2-photon microscope. With this class you can create "scanAndAcquire_OO" OBJECT in 
    % the base workspace. An OBJECT has PROPERTIES and METHODS. In this case, the PROPERTIES 
    % define the scanning parameters. e.g. the image size, the sample rate, where to save 
    % the data, etc. The METHODS are functions that operate on those properties. In this 
    % case the METHODS do things like build the scan waveforms, start scanning, stop 
    % scanning, etc. 
    %
    % The object-oriented approach has some advantages over the procedural approach for 
    % things like data acquisition and GUIs. The principle advantages are:
    % a) It's easier to interact with an object at the command when doing DAQ-related
    %   tasks. The object persists and you start or stop acuisition or change parameters.
    % b) It's very easy to integrate an object into a GUI.
    %   
    % For instance, in the procedural approach (e.g. scanAndAcquire_Polished) you call the 
    % function with the desired scanning paramaters, the function connects to the acquisition 
    % hardware and scanning begins. When you stop scanning the connection with the hardware
    % is broken off. With the object-oriented approach, you make an instance of the object:
    % >> S = scanAndAcquire_OO;
    %
    % Then you can start scanning like this:
    % >> S.startScan
    %
    % And change setting on the fly:
    % >> S.imSize = 512;
    % >> S.sampleRate = 2E6;
    % etc...
    %
    % For incorporation of this class into a GUI see scannerGUI.m
    %
    % 
    % * Details
    % The X mirror should be on AO-0
    % The Y mirror should be on AO-1
    %
    %
    %
    % * Inputs
    % paramFile - (optional) relative or absolute path to an INI file that contains the scan parameters.
    %             By default the first 'scannerConf.ini' file in the path is loaded. Read scannerConf.ini
    %             to see how to configure your acquisition settings.
    %
    %
    %
    % * Examples
    % ONE
    % >> S = scanAndAcquire_OO;
    % % Acquire 10 seconds of data
    % >> S.startScan; pause(10); S.stopScan
    % >> delete(S) %close down the session
    %
    %
    %
    % Rob Campbell - Basel 2015



    properties
        % Properties that hold handles to important objects
        % For details on what these do, please see scannerConf.ini
        %
        % Default settings that can be over-ridden by the user to change scan settings
        % even after the object has been instantiated. Most of these paramaters are set 
        % via setters to allow the user to change the values during scanning and have the
        % scanner seamlessly re-set and begin scanning with the new parameters. 
        % The setters also contain code to validate the value provided (see below).

        deviceID
        samplesPerPixel
        imSize
        scanPattern
        fillFraction
        scannerAmplitude
        invertSignal
        bidiPhase
        shutterLine
        shutterOpenTTLState
        shutterDelay

        saveFname %This is not defined in the INI file
    end %close properties

    properties (Dependent)
        sampleRate
        AIrange   
        inputChans
    end %close dependent properties
    
    properties (Hidden)
        %Properties that hold handles to important objects
        hDAQ      % The DAQ device object
        hAI       % Analog input channels (this is just a reference to the AI channels in hDAQ)
        hDIO      % Session for shutter line. Separate from hDAQ

        numFrames % Counter for number of frames acquired 
        startTime % Serial date at start of scan
        getDataListener         % Listener that pulls in data off the DAQ after each frame
        queueWaveformsListener  % Listern that sends galvo waveform data to DAQ buffer
        figureHandles    % Keep figure handles here
        lastFrameEndTime % DAQ time stamp associated with end of last frame
        
        % Data from the last frame are stored here.
        imageDataFromLastFrame % An array of size: imageRows x imageCols x numChannels

        % A structure populated by prepareQueueAndBuffer
        scanQueue = struct('galvoWaveformData', [], ...
                            'numFramesInQueue', [], ...
                            'pointsPerLine', [])

        %Settings that are unlikely to need changing
        maxScannerVoltage
        minSecondsOfBufferedData
    end %close properties (Hidden)


    properties (Access=private)
        sessionType = 'ni'      % We will work with NI hardware
        measurementType = 'Voltage' % We will acquire voltage data 
        scannerChannels = 0:1   % These are the AO channels to which the scanners are connected [x,y]
    end %close properties (Access=private)


    events
        frameAcquired %Listener to signal to other code that a frame has been acquired (see getDataFromDAQ.m)
    end %close events



    methods
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        %CONSTRUCTOR
        function obj = scanAndAcquire_OO(paramFile)
            % function obj = scanAndAcquire_OO(paramFile)
            %
            % This method is known as a "constructor". It has the same name as the class and is run
            % when an instance of the object is created. 
            %
            % In this case the constructor handles input arguments and then connects to the DAQ


            %Extract parameters from INI file
            if nargin<1
                paramFile=[];
            end

            %Ensure that we have all required directories in the path
            path2file=regexprep(which(mfilename),'@.*','');
            %this covers us for cases where people CD to the directory to start the program but did not add it to the path
            addpath(path2file,'-end') 
            dirsToAdd={'utils'};
            for ii=1:length(dirsToAdd)
                addpath(fullfile(path2file,dirsToAdd{ii}),'-end')
            end

            %Read parameters from the default file
            params = readScannerINI(paramFile);

            %Set the scan pattern variables
            obj.imSize           = params.waveforms.imSize;
            obj.samplesPerPixel  = params.waveforms.samplesPerPixel;
            obj.fillFraction     = params.waveforms.fillFraction;
            obj.scanPattern      = params.waveforms.scanPattern;
            obj.scannerAmplitude = params.waveforms.scannerAmplitude;

            obj.minSecondsOfBufferedData = params.waveforms.minSecondsOfBufferedData;
            if ~obj.checkScanParams %This method returns false if the scan prameter settings are not valid
                fprintf('\n PLEASE CHECK YOUR SCANNER SETTINGS then run connectToDAQ\n\n')
                return
            end

            %Set the device ID and connect to the DAQ
            obj.deviceID = params.DAQ.deviceID;
            obj.shutterLine=params.image.shutterLine;
            obj.connectToDAQ

            %Dependent properties (those that are really read from the DAQ,
            %for the most part) need to be set after the connection to the
            %DAQ has been made.
            obj.sampleRate  = params.DAQ.sampleRate;
            obj.AIrange     = params.DAQ.AIrange;
            obj.inputChans  = params.DAQ.inputChans; %the channels are added here (see setters, below)
            obj.maxScannerVoltage = params.DAQ.maxScannerVoltage;

            % The following settings influence how the data are plotted
            obj.invertSignal = params.image.invertSignal;
            obj.bidiPhase    = params.image.bidiPhase;

            %The following settings influence how the shutter behaves
            obj.shutterOpenTTLState = params.shutter.shutterOpenTTLState;
            obj.shutterDelay        = params.shutter.shutterDelay;
    end %close constructor



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        %DESTRUCTOR
        function delete(obj)
            % The destructor is run when the object is deleted
            obj.stopAndDisconnectDAQ; %stop and don't report the number of acquired frames
            delete(obj.getDataListener)
            delete(obj.queueWaveformsListener)
            
            if ~isempty(obj.figureHandles)
                delete(obj.figureHandles.fig)
            end
        end %close destructor




        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % Short methods follow. Longer ones in standalone .m files in the "@" directory
        function startScan(obj)
            % function startScan(obj,setupFreshFigWindow)
            % Start scanning 

            %Check if running before carrying on
            if obj.hDAQ.IsRunning
                return
            end

            obj.setUpFigureWindow %Only runs if the figure window is not already open

            obj.openShutter
            obj.prepareQueueAndBuffer %TODO: test if data have been queued or just run this each time?

            obj.startTime=now;
            obj.numFrames=0;
            obj.hDAQ.startBackground %start the acquisition in the background
        end %close startScan

        function stopScan(obj,reportFramesAcquired)
            % function stopScan(obj,reportFramesAcquired)

            %Check if now running before carrying on
            if ~obj.hDAQ.IsRunning
                return
            end

            if nargin<2
                reportFramesAcquired=true;
            end

            obj.hDAQ.stop; 
            obj.closeShutter
            if reportFramesAcquired
                if obj.numFrames==0
                    fprintf('\nSomething went wrong. No frames were acquired.\n')
                else
                    fprintf('Acquired %d frames in %0.1f seconds\n', obj.numFrames, (now-obj.startTime)*60^2*24)
                end
            end
        end %close stopScan

        function restartScan(obj)
            % This function is used to stop and restart a scan. 
            % Useful in cases when a scanning parameter is altered and we want this
            % to take effect.
            if obj.hDAQ.IsRunning
                obj.stopScan(0)
                obj.startScan
            end
        end %close restartScan
        
        function openShutter(obj)
            if ~isempty(obj.hDIO)
                obj.hDIO.outputSingleScan(obj.shutterOpenTTLState)
                pause(obj.shutterDelay)
            end
        end %close openShutter
        
        function closeShutter(obj)
            if ~isempty(obj.hDIO)
                obj.hDIO.outputSingleScan(~obj.shutterOpenTTLState)
                pause(obj.shutterDelay)
            end
        end %close closeShutter
            
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

        function figCloseAndStopScan(obj,~,~)
            %Is called when the scan window closes. It stops the scan before closing the window
            fprintf('Closing window and stopping scan\n')
            obj.stopScan
            obj.closeScanWindow
        end

        function closeScanWindow(obj)
            % Close the figure window on which the images are being streamed
            % If a window already exists, we don't make a new one
            if obj.scanWindowPresent
                delete(obj.figureHandles.fig)
            end
        end

        function windowPresent = scanWindowPresent(obj)
            % Return true if a valid scan window is present
            % Return false otherwise
            if ~isempty(obj.figureHandles) && ...
                    isa(obj.figureHandles.fig,'matlab.ui.Figure') && ...
                    isvalid(obj.figureHandles.fig)
                windowPresent = true;
            else
                windowPresent = false;
            end
        end %close scanWindowPresent

        % Getters and setters for properties which require connected DAQ objects to be updated.
        % A setter is run when a value is assigned to a property. It modifies the DAQ object.
        % The getters read back a property from the DAQ object (obj.hDAQ)

        %AIrange
        function set.AIrange(obj,val)
            % Sets the analog input range (the range over which the DAQ digitizes)
            % If the acquisition is running, it is first stopped, the range changed,
            % then it is restarted.
            if isempty(obj.hAI)
                return
            end
            running = obj.hDAQ.IsRunning;
            if running
                obj.stopScan
            end

            for ii=1:length(obj.hAI)
                obj.hAI(ii).Range = [-val,val];
            end

            if running
                obj.startScan
            end
        end
        function AIrange = get.AIrange(obj)
            if isempty(obj.hDAQ)
                AIrange=[];
                return
            end
            AIrange = obj.hAI(1).Range.Max; %all inputs have the same range (see setter, above)
            %AIrange = abs(AIrange);
        end


        %sampleRate
        function set.sampleRate(obj,val)
            % sets sampleRate. See set.AIrange, above, for details
            if isempty(obj.hDAQ)
                return
            end
            running = obj.hDAQ.IsRunning;
            if running
                obj.stopScan;
            end

            obj.hDAQ.Rate = val;
            %TODO: report frame rate
            if running
                obj.startScan;
            end
        end
        function sampleRate = get.sampleRate(obj)
            if isempty(obj.hDAQ)
                sampleRate=[];
                return
            end
            sampleRate = obj.hDAQ.Rate;
        end


        %input channels
        function set.inputChans(obj,chansToAdd)
            if isempty(obj.hDAQ)
                return
            end

            running = obj.hDAQ.IsRunning;
            if running
                obj.stopScan
                obj.closeScanWindow %close the figure window so it's re-drawn with the new channel config
            end

            %Remove the existing analog input channels
            chans=find(strncmp('ai',{obj.hDAQ.Channels.ID},2));
            if ~isempty(chans)
                obj.hDAQ.removeChannel(chans) %warning: set method should not access other prop
            end

            %Add the new channels
            obj.hAI=obj.hDAQ.addAnalogInputChannel(obj.deviceID, chansToAdd, obj.measurementType); 
            obj.AIrange = obj.AIrange; %Apply the current analog input range to these new channels (TODO: may be dangerous)

            if running
                obj.startScan
            end
        end
        function inputChans = get.inputChans(obj)
            %Report the connected analog input channels
            if isempty(obj.hAI)
                inputChans = [];
                return
            end
            inputChans = {obj.hAI.ID};          
        end     


        % The following are setters for the scan waveforms. Each setter will re-start a scan if it's on-going.
        % The effect of this is to re-build the galvo waveforms and begin scanning with new waveforms.
        function set.scannerAmplitude(obj,val)
            if ~isscalar(val) || ~isnumeric(val)
                return
            end
            val = abs(val);
            if val>10
                val=10;
                fprintf('Scanner amplitude capped to 10V\n')
            end
            obj.scannerAmplitude = val;
            obj.restartScan %only restarts if it's already running
        end
        function set.samplesPerPixel(obj,val)
            if ~isscalar(val) || ~isnumeric(val) || val<1
                return
            end
            obj.samplesPerPixel = val;
            obj.restartScan
        end
        function set.imSize(obj,val)
            if ~isscalar(val) || ~isnumeric(val) || val<1
                return
            end
            obj.imSize = val;
            obj.restartScan
        end     
        function set.scanPattern(obj,val)
            if ~strcmpi('bidi',val) &&  ~strcmpi('uni',val)
                return
            end
            obj.scanPattern = val;
            obj.restartScan
        end 
        function set.fillFraction(obj,val)
            if ~isscalar(val) || ~isnumeric(val) || val>1 || val<0
                return
            end
            obj.fillFraction = val;
            obj.restartScan
        end 

    end %close methods

    methods (Hidden)
        function frame = buildImageFromOneChannel(obj,imData,channelColumn)
            % function frame = buildImageFromOneChannel(obj,imData,channelColumn)
            %
            % Construct a square image from column "channelColumn" in the 
            % nSamples-by-cChannels array, imData, that has come off the 
            % acquisition card. Turn-around artifact removed.

            %Average all points from the same pixel
            frame = imData(:,channelColumn);
            frame = mean(reshape(frame,obj.samplesPerPixel,[]),1)'; %Average all points from the same pixel
            %Create a square image of the correct orientation
            frame = reshape(frame, [], obj.imSize); 
            frame = rot90(frame);

            if obj.invertSignal
                frame=-frame;
            end


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
