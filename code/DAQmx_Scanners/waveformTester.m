classdef waveformTester < handle
    % Minimal code needed to acquire data from one channel of a 2-photon microscope
    %
    % waveformTester
    %
    %
    % Description:
    % This is a tutorial class to explore the scan waveform. The waveform for the X mirror
    % is played out of AO0 and sent to the X scan control card. It's also copied to AI0. 
    % AI1 gets the galvo position feedback signal. Parameters are set by editing the properties.
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
    % The following example shows how to list the available DAQ devices and start
    % waveformTester.
    %
    % >> listDeviceIDs
    % The devices on your system are:
    %     aux1
    %     aux2
    %     Dev1
    %     scan
    %
    % >> S=waveformTester('Dev2') % By default it's 'Dev1'
    % >> S.stop  % stops the scanning
    % >> S.start % re-starts the scanning
    % >> S.delete % (or close the figure window)
    %
    %
    % % Acquire using 'Dev1' and save data to a file
    % >> S = waveformTester('Dev1','testImageStack.tiff')
    %
    % Requirements
    % DAQmx and the Vidrio dabs.ni.daqmx wrapper
    %
    % See Also:
    % minimalScanner



    % Define properties that we will use for the acquisition. The properties are "protected" to avoid
    % the user changing them at the command line. Doing so would cause the acquisition to exhibit errors
    % because there is no mechanism for handling changes to these parameters on the fly.
    properties (SetAccess=private)
        % These properties are specific to scanning and image construction
        galvoAmp = 1.5             % Scanner amplitude (defined as peak-to-peak/2)
        pixelsPerLine = 256        % Number pixels per line
        waveform                   % The scanner waveforms will be stored here
        numReps=4                  % How many times to repeat this waveform in one acquisiion
        fillFraction = 0.85        % 1-fillFraction is considered to be the turn-around time and is excluded from the image


        % Properties for the analog input end of things
        hAITask %The AI task handle will be kept here

        AIChan = [0,1] 
        AIterminalConfig = 'DAQmx_Val_PseudoDiff' %Valid values: 'DAQmx_Val_Cfg_Default', 'DAQmx_Val_RSE', 'DAQmx_Val_NRSE', 'DAQmx_Val_Diff', 'DAQmx_Val_PseudoDiff'
        AIrange = 0.5  % Digitise over +/- this range. 

        % Properties for the analog output end of things
        hAOTask % The AO task handle will be kept here
        AOChans = 0

        % These properties are common to both tasks
        DAQDevice = 'Dev1'
        sampleRate = 128E3  % The sample rate at which the board runs (Hz)
    end % close properties block


    properties (Hidden,SetAccess=private)
        % These properties hold information relevant to the plot window
        % They are hidden as well as protected for neatness.
        hFig    % The handle to the figure which shows the data is stored here
        hAxes  % Handle for the image axes
        hPltData     % Handle produced by imagesc
        hTitle  % Handle that stores the plot title
    end




    methods

        function obj=waveformTester
            % This method is the "constructor", it runs when the class is instantiated.


            % Call a method to connect to the DAQ. If the following line fails, the Tasks are
            % cleaned up gracefully and the object is deleted. This is all done by the method
            % call and by the destructor
            obj.connectToDAQandSetUpChannels


            fprintf('Please see "help waveformTester" for usage information\n')

            % Build the figure window and have it shut off the acquisition when closed.
            obj.hFig = clf;
            set(obj.hFig, 'Name', 'Close figure to stop acquisition', 'CloseRequestFcn', @obj.windowCloseFcn)

            %Make an empty axis and fill with a blank image
            obj.hAxes = axes('Parent', obj.hFig, 'Position', [0.05 0.05 0.9 0.9]);
            obj.hPltData = plot(obj.hAxes, obj.waveform);
            set(obj.hAxes, 'Box', 'on')


            % Start the acquisition
            obj.start
            fprintf('Close figure to quit acquisition\n')
        end % close constructor


        function delete(obj)
            % This method is the "destructor". It runs when an instance of the class is deleted.
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

                obj.hAITask.cfgSampClkTiming(obj.sampleRate,'DAQmx_Val_ContSamps', size(obj.waveforms,1) * 4);

                % Call an anonymous function function to read from the AI buffer and plot the images once per frame
                obj.hAITask.registerEveryNSamplesEvent(@obj.readAndDisplayScanData, size(obj.waveforms,1), false, 'Scaled');


                % * Set up the AO task
                % Set the size of the output buffer
                obj.hAOTask.cfgSampClkTiming(obj.sampleRate, 'DAQmx_Val_ContSamps', size(obj.waveforms,1));


                if obj.hAOTask.sampClkRate ~= obj.hAITask.sampClkRate
                    fprintf(['WARNING: AI task sample clock rate does not match AO task sample clock rate. Scan lines will precess.\n', ...
                        'This issue is corrected in polishedScanner, which uses a shared sample clock between AO and AI\n'])
                end

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
            try
                obj.hAOTask.start();
                obj.hAITask.start();
            catch ME
                errorDisplay(ME)
                %Tidy up if we fail
                obj.delete
            end
        end %close start


        function stop(obj)
            % Stop the AI and then AO tasks
            fprintf('Stopping the scanning AI and AO tasks\n');
            obj.hAITask.stop;    % Calls DAQmxStopTask
            obj.hAOTask.stop;
        end %close stop


        function generateScanWaveforms(obj)
            % This method builds a simple ("unshaped") galvo waveform and stores it in the obj.waveform

            % The X waveform goes from +galvoAmp to -galvoAmp over the course of one line.
            xWaveform = linspace(-obj.galvoAmp, obj.galvoAmp, obj.pixelsPerLine); 

            % Repeat the X waveform a few times to ease visualisation on-screen
            obj.waveform = repmat(xWaveform, 1, obj.numReps);

            %Report waveform properties
            fprintf('Scanning with a waveform of length %d and a line period of %0.3f ms\n', ...
             obj.imSize, (obj.sampleRate/length(obj.waveforms))*obj.numReps*1E3 );

        end %close generateScanWaveforms


        function readAndDisplayScanData(obj,src,evnt)
            % This callback method is run each time data have been acquired.
            % This happens because the of the listener set up in the method connectToDAQandSetUpChannels
            % on the "obj.hAITask.registerEveryNSamplesEvent" line.

            % Read data off the DAQ
            inData = readAnalogData(src,src.everyNSamples,'Scaled');

            obj.hPltData.YData = inData(:,1);

        end %close readAndDisplayScanData



        function windowCloseFcn(obj,~,~)
            % This runs when the user closes the figure window or if there is an error
            % Note it's also possible to run a clean-up callback function with hTask.registerDoneEvent

            fprintf('You closed the window. Shutting down DAQ.\n')
            obj.delete % simply call the destructor
        end %close windowCloseFcn

    end %close methods block

end %close the vidrio.mixed.waveformTester class definition 



% Private functions not part of the class definition
function errorDisplay(ME)
    fprintf('ERROR: %s\n',ME.message)
    for ii=1:length(ME.stack)
        fprintf(' on line %d of %s\n', ME.stack(ii).line,  ME.stack(ii).name)
    end
    fprintf('\n')
end
