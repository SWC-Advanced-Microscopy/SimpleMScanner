classdef scannerGUI < handle

% The scannerGUI class is used to build a GUI that controls
% scanAndAcquire_OO
%
% simply run "scannerGUI" to start.
% if scanAndAcquire_OO has not already been started, scannerGUI will do so


	properties
		gui 	 %Stores the GUI handles
		scanner  %Stores the scanAndAcquire_OO object
	end

	properties (Hidden)
		scanning=0
	end

	methods

		function obj=scannerGUI(deviceID,varargin)

			%Import BakingTray object from base workspace			
			obj.scanner = getScannerObjectFromBaseWorkSpace; %function in "private" directory
			if isempty(obj.scanner)
				obj.scanner = scanAndAcquire_OO(deviceID,varargin{:});
			end

			%Build GUI and return handles
			obj.gui = scannerGUI_fig;

			%Attach callbacks to buttons is BT is available
			if isempty(obj.scanner)
				fprintf('Not attaching button callbacks: BakingTray is not available')
				return
			end

    		set(obj.gui.startStopScan,'Callback',@(~,~) obj.startStopScan);


		    set(obj.gui.hFig,'CloseRequestFcn', @(~,~) obj.figClose);

		end

		function delete(obj)


		end

		function figClose(obj)
			%Close figure then run destructor
			delete(obj.gui.hFig)
			obj.scanner.stopScan
			obj.delete
		end

		function startStopScan(obj)
			if obj.scanning
				obj.scanner.stopScan
				obj.scanning=0;
				set(obj.gui.startStopScan, ...
					'Value', obj.scanning, ...
					'ForeGroundColor', 'g', ...
					'String', 'START SCAN');
			else
				%Open a figure in the top right of the screen
				thisFig=figure;
				movegui(thisFig,'northwest')

				obj.scanner.startScan
				obj.scanning=1;
				set(obj.gui.startStopScan, ...
					'Value', obj.scanning, ...
					'ForeGroundColor', 'r', ...
					'String', 'STOP SCAN');
			end
		end

	end

end

