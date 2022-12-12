% VTL prototype
% -------------------------------------------------------------------------
%
% GNSS-SDR is a Global Navigation Satellite System software-defined receiver.
% This file is part of GNSS-SDR.
%
% Copyright (C) 2010-2019  (see AUTHORS file for a list of contributors)
% SPDX-License-Identifier: GPL-3.0-or-later
%
% -------------------------------------------------------------------------
%
%%
clc
close all
clearvars 

% if ~exist('gps_l1_ca_read_pvt_raw_dump.m', 'file')
%     addpath('./libs')
% end
% 
% if ~exist('cat2geo.m', 'file')
%     addpath('./libs/geoFunctions')
% end
SPEED_OF_LIGHT_M_S=299792458.0;
Lambda_GPS_L1=0.1902937;
point_of_closure=6000;

%% ==================== VARIANCES =============================
pos_var=100;%m^2
vel_var=10;%m^2/s^2
clk_bias_var=40;%m^2
clk_drift_var=1500;%m^2/s^2
pr_var=10;%m^2
pr_dot_var=30;%m^2/s^2

% CARLES PAPER LTE GNSS VTL
% pos_var=2;%m^2
% vel_var=0.2;%m^2/s^2
% clk_bias_var=1e-7;%m^2
% clk_drift_var=1e-4;%m^2/s^2
% pr_var=20;%m^2
% pr_dot_var=3;%m^2/s^2
%% ============================================================
samplingFreq=5000000;
channels=6;
TTFF_sec=41.48;
spirent_index_TTFF=416;

plot_skyplot=0;
plot_reference=1;
load_observables=1;

%% ============================ PARSER TO STRUCT ============================

navSolution = GnssSDR2struct('PVT_raw.mat');
refSolution = SpirentMotion2struct('..\log_spirent\motion_V1_SPF_LD_05.csv');
%
load observables\observable_raw.mat
% refSatData = SpirentSatData2struct('..\log_spirent\sat_data_V1A1_SPF_LD_05.csv');
rx_PRN=[28 4 17 15 27 9]; % for SPF_LD_05.
load('PVT_raw.mat','sat_posX_m','sat_posY_m','sat_posZ_m','sat_velX','sat_velY'...
        ,'sat_velZ','sat_prg_m','clk_bias_s','clk_drift','sat_dopp_hz','user_clk_offset')

if(load_observables)
    load observables\observable_raw.mat
    refSatData = SpirentSatData2struct('..\log_spirent\sat_data_V1A1_SPF_LD_05.csv');
end
%%
% vtlSolution = Vtl2struct('dump_vtl_file.csv');
%%

kf_prototype

%% ====== FILTERING =======================================================
% moving_avg_factor= 500;
% LAT_FILT = movmean(navSolution.latitude,moving_avg_factor);
% LON_FILT = movmean(navSolution.longitude,moving_avg_factor);
% HEIGH_FILT = movmean(navSolution.height,moving_avg_factor);
% 
% X_FILT = movmean(navSolution.X,moving_avg_factor);
% Y_FILT = movmean(navSolution.Y,moving_avg_factor);
% Z_FILT = movmean(navSolution.Z,moving_avg_factor);
% 
% vX_FILT = movmean(navSolution.vX,moving_avg_factor);
% vY_FILT = movmean(navSolution.vY,moving_avg_factor);
% vZ_FILT = movmean(navSolution.vZ,moving_avg_factor);
% 
%%
%general_raw_plot
vtl_general_plot

%% ============================================== ==============================================
%%
figure;plot(navSolution.RX_time-navSolution.RX_time(1),kf_yerr(1:5,:)');title('c pr m-error');xlabel('t U.A');ylabel('pr m [m]');grid minor
legend('PRN 28','PRN 4','PRN 17','PRN 15','PRN 27','Location','eastoutside')
figure;plot(navSolution.RX_time-navSolution.RX_time(1),kf_yerr(6:10,:)');title('c pr m DOT-error');xlabel('t U.A');ylabel('pr m dot [m/s]');grid minor
legend('PRN 28','PRN 4','PRN 17','PRN 15','PRN 27','Location','eastoutside')

