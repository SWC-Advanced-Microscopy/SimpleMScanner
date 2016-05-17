function dataToPlay = generateGalvoWaveforms(imSize,scanAmplitude,samplesPerPoint,fillFraction,scanPattern)
% Produce galvo wavorms for 2-photon microscope scanning 
%
% function dataToPlay = generateGalvoWaveforms(imSize,scanAmplitude,samplesPerPoint,fillFraction,scanPattern)
%
% Purpose
% Generates the galvo waveforms for a 2-photon microscope. Patterns for square images only are produced.
%
% 
% Inputs
% imSize - Scalar defining the number of rows and columns in the image. 
%          e.g. if imSize is 256, then a 256 by 256 image is produced
% scanAmplitude - Scalar defining the maximum (+/-) voltage of the waveform. 
%          e.g. if scanAmplitude is 2 then data are acquired using waveform 
%           command voltages going between +/- 2 (but see "fillFraction")
% samplesPerPoint - Scalar defining the number of samples contributing to each pixel. Increasing
%           this value will increase image quality but decrease frame rate.
% fillFraction - Scalar (0 to 1) defining what proportion of the waveform to keep and 
%           use for image formation. This is used to remove the x mirror turn-around 
%           artefacts. e.g. if fillfraction is 0.9, we will remove the outer 10% of the waveform. 
%           In order to maintain a square image, we increase the size of the scanned area to compensate.
% scanPattern - 'bidi' or 'uni' (uni by default)
%
%
% Outputs
% dataToPlay - an N-by-2 array of values corresponding to the galvo waveforms for one frame.
%              First column is X waveform and second is Y waveform.
%
%
% Rob Campbell - Basel 2016
	
	%Check the input arguments
	if ~isscalar(imSize)
		error('imSize should be a scalar\n')
	end
	if ~isscalar(scanAmplitude)
		error('scanAmplitude should be a scalar\n')
	end
	if ~isscalar(samplesPerPoint)
		error('samplesPerPoint should be a scalar\n')
	end
	if ~isscalar(fillFraction)
		error('fillFraction should be a scalar\n')
	end
	if nargin<5
		scanPattern='uni';
	end
	if ~ischar(scanPattern)
		error('scanPattern should be a string')
	end
	if ~strcmpi(scanPattern,'uni') && ~strcmpi(scanPattern,'bidi')
		error('scanPattern must be the string "uni" or "bidi"')
	end


	%Ensure scan amplitude isn't too large (scanners take +/- 10V)
	scanAmplitude = abs(scanAmplitude);
	if scanAmplitude>10
		error('scanAmplitude should be less than 10')
	end

	%Check that, after accounting for the fillFraction, we won't get an X waveform lare than 10V
	fillFractionExcess = 2-fillFraction; %The proprotional increase in scanned area along X
	if scanAmplitude*fillFractionExcess > 10
		error('The scanner waveform will be >10 V after taking into account the fillFraction')
	end



	% Calculate the number of samples per line. We want to produce a final image composed of
	% imSize data points on each line. However, if the fill fraction is less than 1, we
	% need to collect more than this then trim it back when we build the image. 
	correctedPointsPerLine = ceil(imSize*fillFractionExcess); %collect more points along X if fillFraction < 1


	%The number of samples collected per line will scale with the number of samples per point
	samplesPerLine = correctedPointsPerLine*samplesPerPoint; 


	%Produce the Y waveform
	yWaveform = linspace(scanAmplitude, -scanAmplitude, samplesPerLine*imSize);


	%Produce the X waveform
	xScanAmp = scanAmplitude*fillFractionExcess;
	xWaveform = linspace(-xScanAmp, xScanAmp, samplesPerLine);

	if strcmpi(scanPattern,'bidi')
		xWaveform = [xWaveform,fliplr(xWaveform)];
	end

	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));


	%Assemble the two waveforms into an N-by-2 array that can be sent to the NI board
	dataToPlay = [xWaveform(:),yWaveform(:)];



