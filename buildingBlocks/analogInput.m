function out = analogInput
% Record two seconds of data and return it as an output variable and plot it to screen
%
%
% Rob Campbell - Basel 2015


%Create a session using NI hardware
s=daq.createSession('ni');


%Add an analog input channel
AI=s.addAnalogInputChannel('Dev1', 'ai0', 'Voltage');
AI.Range = [-10,10]; %record over +/- 10 V


%Add a listener to get data back from this channel (TODO!) and plot it
addlistener(s,'DataAvailable', @plotData); 


%Set the sample rate
s.Rate = 1E3;


%when to read back after two seconds
s.NotifyWhenDataAvailableExceeds=s.Rate*2;



%start the acquisition and block until finished
s.startForeground 



% - - - - - - - - - - - - - - - - - - - - -
function plotData(~,event)
	t=event.TimeStamps;
	x=event.Data;
 
	plot(t,x)
