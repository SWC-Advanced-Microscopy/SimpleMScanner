classdef scannerGUI < handle

% The scannerGUI class is used to build a GUI that controls scanAndAcquire_OO
%
% scannerGUI(deviceID,'param1',val1,'param2',val2,...)
% 
% Purpose
% scannerGUI is a GUI wrapper for scanAndAcquire_OO. It is not complete. 
% The purpose of scannerGUI is to show how a graphical interface and be written
% around an existing object in a modular manner. In this case there are three modules:
% 1) The GUI (figure window) itself that is built by scannerGUI_fig
% 2) scanAndAcquire_OO that controls the scanner and shows the images on screen.
% 3) This scannerGUI class that links the UI elements in the figure with methods 
%    and properties in the scanAndAcquire_OO object. 
%
% Usage
% There are two ways of starting scannerGUI. One is to first create an instance of 
% scanAndAcquire_OO and then to call scannerGUI. In this scenario, scannerGUI finds
% the scanAndAcquire_OO object in the base workspace and connects to it:
% >> S=scanAndAcquire_OO('Dev1');
% >> scannerGUI;
%
% The other scenario is to call scannerGUI using the same input arguments as would for 
% scanAndAcquire_OO. If you do this, an instance of scanAndAcquire_OO is created and
% then the GUI loads:
% >> S = scannerGUI('Dev1');
%
%
% Rob Campbell - Basel 2016
%
% Also see:
% scannerGUI_fig, scanAndAcquire_OO


	properties % These are the properties ("variables") associated with the scannerGUI class
		gui 	 %Stores the GUI handles
		scanner  %Stores the scanAndAcquire_OO object
	end


	methods % Here are the methods ("functions") available to the user

		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		%CONSTRUCTOR
		function obj=scannerGUI(deviceID,varargin)

			%Import BakingTray object from base workspace			
			obj.scanner = getScannerObjectFromBaseWorkSpace; %function in "private" directory
			if isempty(obj.scanner)
				fprintf('Creating instance of scanAndAcquire_OO\n')
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
    		set(obj.gui.bidi,'Callback',@(~,~) obj.bidiScan);

		    set(obj.gui.hFig,'CloseRequestFcn', @obj.scannerGUIClose);

		end

		function delete(obj)


		end
		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		%DESTRUCTOR
		function delete(obj)
			%NOTHING HERE YET
		end %close destructor

		function scannerGUIClose(obj,~,~)
			%Close figure then run destructor
			obj.scanner.stopScan
			delete(obj.gui.hFig)
		end



		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		%The following are callback functions that are linked to UI elements

		function startStopScan(obj)
			isRunning = obj.scanner.hDAQ.IsRunning;
			if isRunning
				obj.scanner.stopScan

				set(obj.gui.startStopScan, ...
					'Value', isRunning, ...
					'ForeGroundColor', 'g', ...
					'String', 'START SCAN');
			else
				%Open a figure in the top right of the screen
				thisFig=figure;
				movegui(thisFig,'northwest')
				obj.scanner.startScan
				set(obj.gui.startStopScan, ...
					'Value', isRunning, ...
					'ForeGroundColor', 'r', ...
					'String', 'STOP SCAN');
			end
		end	%close startStopScan

		function bidiScan(obj)

			if obj.gui.bidi.Value
				obj.scanner.scanPattern='bidi';
			else
				obj.scanner.scanPattern='uni';
			end
			obj.scanner.restartScan
		end %close bidiScan

	end %close methods


end %close scannerGUI

