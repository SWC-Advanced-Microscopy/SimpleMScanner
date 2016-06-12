function [out,pathToINI]=readScannerINI(INIfname)
% Read a scanner INI file into a structure
%
% function [out,pathToINI]=readScannerINI(INIfname)
%
% Purpose:
% The INI file called 'scannerConf.ini' is read in and returned aa structure.
% If missing, the default file included with the project is read. This file
% is called scannerConf_DEFAULT
%
% Inputs
% INIfname   - [optional] if empty or missing the string 'scannerConf.ini' is used. 
%
%
% Outputs
% out - the contents of the INI file (plus some minor processing) as a structure
% pathToINI - path to the INI file.
%
%
% Rob Campbell - Basel 2016


if nargin<1 | isempty(INIfname)
    INIfname='scannerConf.ini';
end


%Read INI file
defaultFname='scannerConf_DEFAULT.ini';
if ~exist(defaultFname,'file')
    fprintf('%s can not find file %s. Can not read settings file.\n',mfilename,defaultFname)
    return
end
if exist(INIfname,'file')
    out = readThisINI(INIfname);
    pathToINI = which(INIfname); %So we optionally return the path to the INI file
else
    out = readThisINI(defaultFname);
    pathToINI=[];
    return
end


%Load the default INI file
default = readThisINI(defaultFname);


%Check that the user INI file contains all the keys that are in the default
fO=fields(out);
fD=fields(default);

for ii=1:length(fD)
    if isempty(strmatch(fD{ii},fO,'exact'))
        fprintf('Missing section %s in INI file %s. Using default values\n', fD{ii}, which(INIfname))
        out.(fD{ii}) = default.(fD{ii}) ;
        continue
    end

    %Warning: descends down only one layer
    sO = fields(out.(fD{ii}));
    sD = fields(default.(fD{ii}));
    for jj=1:length(sD)
        if isempty(strmatch(sD{jj},sO,'exact'))
           fprintf('Missing field %s in INI file %s. Using default value.\n',sD{jj}, which(INIfname))
           out.(fD{ii}).(sD{jj}) = default.(fD{ii}).(sD{jj});
        end
    end

end

%Split channels into a cell array of strings
out.DAQ.inputChans = strsplit(out.DAQ.inputChans,',');



function out=readThisINI(fname)
ini = IniConfig();
ini.ReadFile(fname);

sections = ini.GetSections;

for ii=1:length(sections)
    keys = ini.GetKeys(sections{ii});
    values = ini.GetValues(sections{ii}, keys);
    for jj=1:length(values)
        out.(sections{ii}(2:end-1)).(keys{jj})=values{jj};
    end
end
