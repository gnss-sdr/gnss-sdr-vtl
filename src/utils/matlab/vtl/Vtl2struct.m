%% Import data from text file
% Script for importing data from the following text file:
%
%    filename: D:\virtualBOX_VM\ubuntu20\ubuntu20\shareFolder\myWork\results\spirent_usrp_airing\dump_vtl_file.csv
%
% %
% -------------------------------------------------------------------------
%  USE EXAMPLE: vtlSolution = Vtl2struct('dump_vtl_file.csv')
% -------------------------------------------------------------------------

% Auto-generated by MATLAB on 24-Nov-2022 17:34:27
function [vtlSolution] = Vtl2struct(path_to_vtl_csv)
%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 9);

% Specify range and delimiter
opts.DataLines = [1, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["kf_state", "e06", "VarName3", "e06_1", "VarName5", "VarName6", "VarName7", "VarName8", "VarName9"];
opts.VariableTypes = ["char", "double", "double", "double", "double", "double", "double", "double", "double"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "kf_state", "WhitespaceRule", "preserve");
opts = setvaropts(opts, "kf_state", "EmptyFieldRule", "auto");

% Import the data
dumpvtlfile = readtable(path_to_vtl_csv, opts);

%% Convert to output type
dumpvtlfile = table2cell(dumpvtlfile);
numIdx = cellfun(@(x) ~isnan(str2double(x)), dumpvtlfile);
dumpvtlfile(numIdx) = cellfun(@(x) {str2double(x)}, dumpvtlfile(numIdx));

%% Clear temporary variables
clear opts
%%

vtlSolution.kfpvt=[];
vtlSolution.rtklibpvt=[];

%% split by solution type
[indKF,~]= find(strcmp(dumpvtlfile, 'kf_state'));
[indRTKlib,~]= find(strcmp(dumpvtlfile, 'rtklib_state'));
[indkf_err,~]= find(strcmp(dumpvtlfile, 'kf_xerr'));
[ind_LOS,~]= find(strcmp(dumpvtlfile, 'sat_first_LOS'));

kfpvt=dumpvtlfile(indKF,:);kfpvt(:,1)=[];
rtklibpvt=dumpvtlfile(indRTKlib,:); rtklibpvt(:,1)=[];
kferr=dumpvtlfile(indkf_err,:); kferr(:,1)=[];
LOS=dumpvtlfile(ind_LOS,:); LOS(:,1)=[];

kfpvt=cell2mat(kfpvt);
rtklibpvt=cell2mat(rtklibpvt);
kferr=cell2mat(kferr);
LOS=cell2mat(LOS);

vtlSolution.kfpvt.X=kfpvt(:,1);
vtlSolution.kfpvt.Y=kfpvt(:,2);
vtlSolution.kfpvt.Z=kfpvt(:,3);
vtlSolution.kfpvt.vX=kfpvt(:,4);
vtlSolution.kfpvt.vY=kfpvt(:,5);
vtlSolution.kfpvt.vZ=kfpvt(:,6);
vtlSolution.kfpvt.biasclock=kfpvt(:,7);
vtlSolution.kfpvt.rateblock=kfpvt(:,8);

vtlSolution.rtklibpvt.X=rtklibpvt(:,1);
vtlSolution.rtklibpvt.Y=rtklibpvt(:,2);
vtlSolution.rtklibpvt.Z=rtklibpvt(:,3);
vtlSolution.rtklibpvt.vX=rtklibpvt(:,4);
vtlSolution.rtklibpvt.vY=rtklibpvt(:,5);
vtlSolution.rtklibpvt.vZ=rtklibpvt(:,6);
vtlSolution.rtklibpvt.biasclock=rtklibpvt(:,7);
vtlSolution.rtklibpvt.rateblock=rtklibpvt(:,8);

vtlSolution.kferr.X=kferr(:,1);
vtlSolution.kferr.Y=kferr(:,2);
vtlSolution.kferr.Z=kferr(:,3);
vtlSolution.kferr.vX=kferr(:,4);
vtlSolution.kferr.vY=kferr(:,5);
vtlSolution.kferr.vZ=kferr(:,6);
vtlSolution.kferr.biasclock=kferr(:,7);
vtlSolution.kferr.rateblock=kferr(:,8);

vtlSolution.LOSx=LOS(:,1);
vtlSolution.LOSy=LOS(:,2);
vtlSolution.LOSz=LOS(:,3);
end