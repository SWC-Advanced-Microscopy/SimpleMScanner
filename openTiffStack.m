function [im,timeStamps,imInfo] = openTiffStack(fileName)
% Loading a tiff stack into a 3-D array
%
% function [im,timeStamps,imInfo] = openTiffStack(fileName)
%
% 
% Purpose
% Load a TIFF stack into a 3-D array. e.g. an image time-series where 
% third dimension is time.
%
% 
% Inputs
% fileName - relative or full path to the tiff image. (string)
%
%
% Output 
% im - matrix containing the image read from disk.
% timeStamps - vector of time-stamps in ms with respect to the first frame
% imInfo - a structure containing the image header information. 
%
%
% Rob Campbell - Basel 2016
  
  
%% Input parsing
if ~ischar(fileName)
    fprintf('fileName must be a single character array\m')
    return
elseif ~exist(fileName, 'file')
    fprintf('File specified (%s) does not exist', fileName)
    return
end



imInfo = imfinfo(fileName); %Use this to get the number of frames
im = imread(fileName); 

%pre-allocate
im = repmat(im,[1,1,length(imInfo)]);

if length(imInfo)==1
  return
end

%Read in all the frames
for ii=2:length(imInfo)
  im(:,:,ii) = imread(fileName,ii);
end


%Generate time stamps
timeStamps = ones(1,length(imInfo));

for ii=1:length(timeStamps)
  timeStamps(ii) = str2num(imInfo(ii).ImageDescription);
end

timeStamps = timeStamps-timeStamps(1);
