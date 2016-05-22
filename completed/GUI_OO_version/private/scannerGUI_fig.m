function handles = scannerGUI_fig
% Build a GUI for the scanner and return the handles to the plot and ui objects
%	
% function handles = scannerGUI_fig
%
% 




fontSz=12;

handles.hFig = figure;
set(handles.hFig,'ToolBar','none','MenuBar','none','Name','Mover');


%Scan button
handles.startStopScan = uicontrol(...
    'Parent', handles.hFig, ...
    'Units', 'normalized', ...
    'Position', [0.1 0.1 0.12 0.12], ...
    'String', 'SCAN');
