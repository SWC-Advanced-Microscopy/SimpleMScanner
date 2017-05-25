classdef polishedScanner < handle
    % Minimal code needed to acquire data from one channel of a 2-photon microscope
    %
    % polishedScanner
    %
    %
    % Description:
    % This is a tutorial class shows the minimal possible code necessary to get good images 
    % from a 2-photon scanning microscope, and stream the to disk. This class produces 
    % uni-directional galvo waveforms to scan the beam across the sample. It acquires data 
    % from one photo-detector (a PMT or a photo-diode) through a single analog input channel. 
    % This class is a more advanced version of basicScanner.
    %
    % All scanning parameters are hard-coded into the class properties to keep things brief 
    % and focus on how the acquisition is being done. XXX important parameters are added
    % compared to basicScanner:
    %   TODO
    %
    %
    % Instructions
    % Start the class with the device ID of your NI acquisition board as an input argument. 
    % Quit by closing the window showing the scanned image stream. Doing this will gracefully
    % stop the acquisition. 
    % The X mirror should be on AO-0
    % The Y mirror should be on AO-1
    %
    % Inputs
    % hardwareDeviceID - [Optional, default is 'Dev1'] A string defining the device ID of your 
    %                    NI acquisition board. Use the command "daq.getDevices" to find the ID 
    %                    of your board. By default this is 'Dev1'
    % saveFname - An optional string defining the relative or absolute path of a file to which data 
    %             should be written. Data will be written as a TIFF stack. If not supplied, no data 
    %             are saved to disk. 
    %
    %
    %
    % Examples
    % The following example shows how to start polishedScanner and change scan settings on the fly.
    %
    %
    % >> S=polishedScanner('Dev2') % By default it's 'Dev1'
    % >> S.stop   % Stops the scanning
    % >> S.start  % Re-starts the scanning
    % >> S.sampleRate  % Query the sample rate 
    %    ans =
    %       1.2821e+05
    % >> S.FPS  % Query the number of frames per second
    %    ans =
    %       3.3838
    % % Drop down to a slower sample rate and query the FPS again:
    % >> S.sampleRate=32E3;
    % >> S.FPS
    %   ans =
    %      0.8446
    %
    %
    % KNOWN BUGS:
    % Going from smaller to larger image sizes causes a crash when running on a simulated device. 
    %
    %
    % Requirements
    % DAQmx and the Vidrio dabs.ni.daqmx wrapper
    %
    % See Also:
    % basicScanner, minimalScanner



    % TODO: change imSize, fillFraction, samplesPerPixel, and galvo amplitude on the fly
    % TODO: add a start/stop button
    % TODO: add a histogram that can be disabled at the command-line

    % Define properties that we will use for the acquisition. The properties are "protected" to avoid
    % the user changing them at the command line. Doing so would cause the acquisition to exhibit errors
    % because there is no mechanism for handling changes to these parameters on the fly.
    properties (SetAccess=private)
        % These properties are specific to scanning and image construction
        invertSignal = -1    % Set to -1 if using a non-inverting amp with a PMT
        waveforms           % The scanner waveforms will be stored here
        saveFname = ''

        % The following properties are more directly related to setting up the DAQ
        DAQDevice = 'Dev1'

        % Properties for the analog input end of things
        hAITask %The AI task will be kept here

        AIChan = 0 
        AIterminalConfig = 'DAQmx_Val_PseudoDiff' %Valid values: 'DAQmx_Val_Cfg_Default', 'DAQmx_Val_RSE', 'DAQmx_Val_NRSE', 'DAQmx_Val_Diff', 'DAQmx_Val_PseudoDiff'
        AIrange = 0.5  % Digitise over +/- this range. 

        % Properties for the analog output end of things
        hAOTask % The AO task will be kept here
        AOChans = 0:1
    end % close properties block


    properties (Hidden,SetAccess=private)
        % These properties hold information relevant to the plot window
        % They are hidden as well as protected for neatness.
        hFig    % The handle to the figure which shows the data is stored here
        imAxes  % Handle for the image axes
        hIm     % Handle produced by imagesc
        hTitle  % Handle that stores the plot title

        correctedPointsPerLine % Actual number of points we will need to collect, this is a fill-fraction-related parameter
        lastFrame % The last acquired frame is stored here
        currentFrame=1;


        isRunning=0 %Set to 1 if the scanning is running
    end

    properties (Dependent)
        % Dependent properties appear at the command line like regular properties but they don't store data. 
        % Instead, they depend on other properties or methods:
        % https://www.mathworks.com/matlabcentral/answers/128905-how-to-efficiently-use-dependent-properties-if-dependence-is-computational-costly
        % https://www.mathworks.com/help/matlab/matlab_oop/access-methods-for-dependent-properties.html        
        sampleRate % The user can change the sample rate here
        FPS % Returns the number of frames per second
        imSize
        galvoAmp
        fillFraction
        samplesPerPixel
    end

    properties (Hidden)
        % These properties are related to the dependent properties
        desiredSampleRate = 128E3  % The target sample rate for the board to run at (Hz)
        desired_imSize = 256 % Number pixel rows and columns
        desired_galvoAmp =2
        desired_fillFraction = 0.85 % 1-fillFraction is considered to be the turn-around time and is excluded from the image
        desired_samplesPerPixel = 2 % Number of samples to average for each pixel
    end




    methods

        function obj=polishedScanner(deviceID,saveFname)
            % This method is the "constructor", it runs when the class is instantiated.

            if nargin>0
                obj.DAQDevice = deviceID;
            end

            if nargin>1
                obj.saveFname=saveFname;
            end

            fprintf('Please see "help polishedScanner" for usage information\n')

            % Build the figure window and have it shut off the acquisition when closed.
            obj.hFig = clf;
            set(obj.hFig, 'Name', 'Close figure to stop acquisition', ...
             'CloseRequestFcn', @obj.windowCloseFcn, ...
             'Toolbar', 'None')

            %Make an empty axis and fill with a blank image
            obj.imAxes = axes('Parent', obj.hFig, 'Position', [0.05 0.05 0.9 0.9]);
            obj.makeBlankFigure % Add a blank image based upon the current image size

            % Call a method to connect to the DAQ. If the following line fails, the Tasks are
            % cleaned up gracefully and the object is deleted. This is all done by the method
            % call and by the destructor
            obj.connectToDAQandSetUpChannels

            % Start the acquisition
            if isvalid(obj)
                %Report frame rate to screen
                fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n', ...
                 obj.imSize, obj.imSize, obj.FPS);
                obj.start
                fprintf('Close figure to quit acquisition\n')
            end
        end % close constructor


        function delete(obj)
            % This method is the "destructor". It runs when an instance of the class is deleted.
            fprintf('Tidying up polishedScanner\n')
            obj.hFig.delete %Closes the plot window
            obj.stop % Call the method that stops the DAQmx tasks

            % The tasks should delete automatically (which causes dabs.ni.daqmx.Task.delete to 
            % call DAQmxClearTask on each task) but for paranoia we can delete manually:
            obj.hAITask.delete;
            obj.hAOTask.delete;
        end %close destructor


        function connectToDAQandSetUpChannels(obj)
            % Note how we try to name the methods in the most descriptive way possible
            % Attempt to connect to the DAQ and set it up. If we fail, we close the 
            % connection to the DAQ and tidy up
            try 
                % Create separate DAQmx tasks for the AI and AO
                obj.hAITask = dabs.ni.daqmx.Task('signalReceiver');
                obj.hAOTask = dabs.ni.daqmx.Task('waveformMaker');

                %  Set up analog input and output voltage channels
                obj.hAITask.createAIVoltageChan(obj.DAQDevice, obj.AIChan, [], -obj.AIrange, obj.AIrange, [], [], obj.AIterminalConfig);
                obj.hAOTask.createAOVoltageChan(obj.DAQDevice, obj.AOChans);


                % * Set up the AI task

                % Configure the sampling rate and the number of samples so that we are reading back
                % data at the end of each frame 
                obj.generateScanWaveforms %This will populate the waveforms property
                obj.hAITask.cfgSampClkTiming(obj.desiredSampleRate,'DAQmx_Val_ContSamps', size(obj.waveforms,1) * 4, ['/',obj.DAQDevice,'/ao/SampleClock']);

                % Call an anonymous function function to read from the AI buffer and plot the images once per frame
                obj.hAITask.registerEveryNSamplesEvent(@obj.readAndDisplayLastFrame, size(obj.waveforms,1), false, 'Scaled');


                % * Set up the AO task
                % Set the size of the output buffer
                obj.hAOTask.cfgSampClkTiming(obj.desiredSampleRate, 'DAQmx_Val_ContSamps', size(obj.waveforms,1));

                % Allow sample regeneration (buffer is circular)
                obj.hAOTask.set('writeRegenMode', 'DAQmx_Val_AllowRegen');
                % Write the waveform to the buffer with a 5 second timeout in case it fails
                obj.hAOTask.writeAnalogData(obj.waveforms, 5)

                % Configure the AO task to start as soon as the AI task starts
                obj.hAOTask.cfgDigEdgeStartTrig(['/',obj.DAQDevice,'/ai/StartTrigger'], 'DAQmx_Val_Rising');
            catch ME
                    errorDisplay(ME)
                    %Tidy up if we fail
                    obj.delete
            end
        end % close connectToDAQandSetUpChannels


        function start(obj)
            % This method starts acquisition on the AO then the AI task. 
            % Acquisition begins immediately since there are no external triggers.
            if obj.isRunning
                fprintf('Scanning is already running\n')
                return
            end
            try
                obj.hAOTask.start();
                obj.hAITask.start();
            catch ME
                errorDisplay(ME)
                %Tidy up if we fail
                obj.delete
            end
            obj.isRunning=1;
        end %close start


        function stop(obj)
            % Stop the AI and then AO tasks
            obj.hAITask.stop;    % Calls DAQmxStopTask
            obj.hAOTask.stop;
            obj.isRunning=0;
        end %close stop


        function generateScanWaveforms(obj)
            % Calculate the number of samples per line taking into account the fill-fraction. 
            % The fill-fraction is the proportion of each scan line that we keep and use for 
            % image formation. scanAndAcquire_Minimal keeps the whole line. Images from that
            % function show a "turn-around artefact". This occurs when data acquired during the 
            % x-mirror fly-back are used for image formation. The purpose of the fill-fraction
            % setting is to discard these data points and leave us with a clean image. So, if
            % the fill-fraction is 0.9, we discard 10% of the X data and keep the rest. In order
            % to get the number of pixels asked for by the user regardless of the fill fraction we
            % must obtain more data than needed for the final image. Here is how we do this:

            fillFractionExcess = 2-obj.fillFraction; % The proportional increase in scanned area along X due to the fill-fraction
            % So so it's "2-fillFraction" because what we end up doing is acquiring *more* points and trimming the back so if the 
            % user asked for 512x512 pixels this is what they end up getting.

            obj.correctedPointsPerLine = ceil(obj.imSize*fillFractionExcess); % Actual number of points we will need to collect

            % We also make it possible to acquire multiple samples per pixel. So must
            % multiply correctedPointsPerLine by the number of samples per pixel.
            samplesPerLine = obj.correctedPointsPerLine*obj.samplesPerPixel;

            yWaveform = linspace(obj.galvoAmp, -obj.galvoAmp, samplesPerLine*obj.imSize); 

            % The X waveform goes from +galvoAmp to -galvoAmp over the course of one line.
            xWaveform = linspace(-obj.galvoAmp, obj.galvoAmp, samplesPerLine); % One line of X

            % Repeat the X waveform "imSize" times in order to build a square image
            xWaveform = repmat(xWaveform, 1, length(yWaveform)/length(xWaveform)); 

            % Assemble the two waveforms into an N-by-2 array
            obj.waveforms = [xWaveform(:), yWaveform(:)];

        end %close generateScanWaveforms


        function readAndDisplayLastFrame(obj,src,evnt)
            % This callback method is run each time one frame's worth of data have been acquired.
            % This happens because the of the listener set up in the method connectToDAQandSetUpChannels
            % on the "obj.hAITask.registerEveryNSamplesEvent" line.

            % Read data off the DAQ
            rawImData = readAnalogData(src,src.everyNSamples,'Scaled');

            %First we average together all points associated with the same pixel
            obj.lastFrame = mean(reshape(rawImData, obj.samplesPerPixel,[]),1)'; 
            obj.lastFrame = reshape(obj.lastFrame, obj.correctedPointsPerLine, obj.imSize);


            % Now keep only "imSize" pixels from each row. This trims off the excess
            % That comes from fill-fractions less than 1. If the fill-fraction is chosen
            % correctly, the X mirror turn-around artefact is now gone. 
            obj.lastFrame = obj.lastFrame(end-obj.imSize+1:end,:); 

            obj.hIm.CData = rot90(obj.lastFrame) * obj.invertSignal;


            obj.hTitle.String = sprintf('Frame: #%d, %0.2f FPS',obj.currentFrame,obj.FPS);
            obj.currentFrame=obj.currentFrame+1;

            obj.saveLastFrame
        end %close readAndDisplayLastFrame


        function saveLastFrame(obj)
            if ~isempty(obj.saveFname) %Optionally write data to disk
                obj.currentFrame = (obj.currentFrame/obj.AIrange) * 2^16 ; %ensure values span 16 bit range
                obj.currentFrame = uint16(obj.currentFrame); %Convert to unsigned 16 bit integers. Negative numbers will be gone.
                imwrite(obj.currentFrame, obj.saveFname, 'tiff', ...
                        'Compression', 'None', ... %Don't compress because this slows IO
                        'WriteMode', 'Append') 
            end
        end % close saveLastFrame


        function windowCloseFcn(obj,~,~)
            % This runs when the user closes the figure window or if there is an error
            % Note it's also possible to run a clean-up callback function with hTask.registerDoneEvent

            fprintf('You closed the window. Shutting down DAQ.\n')
            obj.delete % simply call the destructor
        end %close windowCloseFcn



    end %close methods block


    % Property get and set methods follow in this block. 
    % We're using a seperate properties block for neatness, it's not necessary
    methods
        function actualSampleRate=get.sampleRate(obj)
            % The actual sample rate likely won't be the desired sample rate
            actualSampleRate = obj.hAOTask.sampClkRate;
        end
        function set.sampleRate(obj, newSampleRate)
            %Do not proceed if the new sample rate is too high for AI or AO
            if scanimage.util.daqTaskGetMaxSampleRate(obj.hAITask)<newSampleRate 
                fprintf('Requested sample rate of %d is higher than the maximum allowed AI sample rate: %d\n',...
                    newSampleRate, round(scanimage.util.daqTaskGetMaxSampleRate(obj.hAITask)) )
                    return
            end
            if scanimage.util.daqTaskGetMaxSampleRate(obj.hAOTask)<newSampleRate 
                fprintf('Requested sample rate of %d is higher than the maximum allowed AO sample rate: %d\n',...
                    newSampleRate, round(scanimage.util.daqTaskGetMaxSampleRate(obj.hAOTask)) )
                    return
            end

            obj.stop
            obj.desiredSampleRate = newSampleRate;
            obj.hAOTask.cfgSampClkTiming(obj.desiredSampleRate, 'DAQmx_Val_ContSamps', size(obj.waveforms,1));
            %report new sample rate to screen
            obj.start
        end

        function fps = get.FPS(obj)
            fps=obj.sampleRate/length(obj.waveforms);
        end

        %The following getters and setters allow changing of scan settings on the fly
        function imSize=get.imSize(obj)
            imSize = obj.desired_imSize;
        end
        function set.imSize(obj,val)
            obj.desired_imSize=val;
            obj.regnerateWaveforms
        end

        function galvoAmp=get.galvoAmp(obj)
            galvoAmp = obj.desired_galvoAmp;
        end
        function set.galvoAmp(obj,val)
            obj.desired_galvoAmp=val;
            obj.regnerateWaveforms
        end

        function fillFraction=get.fillFraction(obj)
            fillFraction = obj.desired_fillFraction;
        end
        function set.fillFraction(obj,val)
            obj.desired_fillFraction=val;
            obj.regnerateWaveforms
        end      

        function samplesPerPixel=get.samplesPerPixel(obj)
            samplesPerPixel = obj.desired_samplesPerPixel;
        end
        function set.samplesPerPixel(obj,val)
            obj.desired_samplesPerPixel=val;
            obj.regnerateWaveforms
        end


    end %close getters and setters methods block


    methods (Hidden)
        function regnerateWaveforms(obj)
            % Regenerates the scan waveforms and send send these to the AO buffer. This method
            % is used when a scanning parameter is changed in order to begin scanning with the 
            % new settings.
            obj.stop
            obj.generateScanWaveforms

            try
                % Set the buffer size
                nSamples=size(obj.waveforms,1);

                % We must unreserve the DAQ device before writing to the buffer:
                % https://forums.ni.com/t5/Multifunction-DAQ/How-to-flush-output-buffer-optionally-resize-it-and-write-to-it/td-p/3138640
                obj.hAOTask.control('DAQmx_Val_Task_Unreserve') 

                obj.hAOTask.cfgSampClkTiming(obj.desiredSampleRate, 'DAQmx_Val_ContSamps', nSamples);
                obj.hAOTask.set('writeRegenMode', 'DAQmx_Val_AllowRegen');

                % Write data to the start of the buffer


                % Write the waveform to the buffer with a 5 second timeout in case it fails
                obj.hAOTask.writeAnalogData(obj.waveforms, 5)
                obj.hAITask.registerEveryNSamplesEvent(@obj.readAndDisplayLastFrame, size(obj.waveforms,1), false, 'Scaled');

            catch ME
                errorDisplay(ME)
                obj.delete
                return
            end

            obj.makeBlankFigure
            obj.start

        end % close regnerateWaveforms

        function makeBlankFigure(obj)
            obj.hIm = imagesc(obj.imAxes,zeros(obj.imSize));
            obj.hTitle = title('');
            set(obj.imAxes, 'XTick', [], 'YTIck', [], 'CLim', [0,obj.AIrange], 'Box', 'on')
            axis square
            colormap gray
        end % close makeBlankFigure

    end %close hidden methods block

end %close the vidrio.mixed.basicScanner class definition 





% Private functions not part of the class definition
function errorDisplay(ME)
    fprintf('ERROR: %s\n',ME.message)
    for ii=1:length(ME.stack)
        fprintf(' on line %d of %s\n', ME.stack(ii).line,  ME.stack(ii).name)
    end
    fprintf('\n')
end
