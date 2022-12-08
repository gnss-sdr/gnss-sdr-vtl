% Read PVG raw dump
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
%%
samplingFreq=5000000;
channels=6;
TTFF_sec=41.48;

%% ============================ PARSER TO STRUCT ============================
plot_skyplot=0;
plot_reference=1;
load_observables=1;
advance_vtl_data_available=1;
load_vtl=1;

navSolution = GnssSDR2struct('PVT_raw.mat');
refSolution = SpirentMotion2struct('..\log_spirent\motion_V1_SPF_LD_05.csv');
%%
if(load_observables)
    load observables\observable_raw.mat
    refSatData = SpirentSatData2struct('..\log_spirent\sat_data_V1A1_SPF_LD_05.csv');
    rx_PRN=[28 4 17 15 27 9]; % for SPF_LD_05.
end

if(advance_vtl_data_available)
    load('PVT_raw.mat','sat_posX_m','sat_posY_m','sat_posZ_m','sat_velX','sat_velY'...
        ,'sat_velZ','sat_prg_m','clk_bias_s','sat_dopp_hz')
end

if(load_vtl)
vtlSolution = Vtl2struct('dump_vtl_file.csv');
end
%% calculate LOS Rx-sat if advance_vtl_data_available=1

if(advance_vtl_data_available)
    for chan=1:5
        for t=1:length(navSolution.RX_time)
            d(chan)=(sat_posX_m(chan,t)-navSolution.X(t))^2;
            d(chan)=d(chan)+(sat_posY_m(chan,t)-navSolution.Y(t))^2;
            d(chan)=d(chan)+(sat_posZ_m(chan,t)-navSolution.Z(t))^2;
            d(chan)=sqrt(d(chan));
            
            pr_m(chan,t)=d(chan)+clk_bias_s(t)*SPEED_OF_LIGHT_M_S;
            
            a_x(chan,t)=-(sat_posX_m(chan,t)-navSolution.X(t))/d(chan);
            a_y(chan,t)=-(sat_posY_m(chan,t)-navSolution.Y(t))/d(chan);
            a_z(chan,t)=-(sat_posZ_m(chan,t)-navSolution.Z(t))/d(chan);
        end
    end
end
%%
% figure;plot([a_x(1,:);a_y(1,:);a_z(1,:)]');
% figure;plot([vtlSolution.LOSx vtlSolution.LOSy vtlSolution.LOSz])
%%
if(advance_vtl_data_available)
    for chan=1:5
        for t=1:length(navSolution.RX_time)
rhoDot_pri(chan,t)=(sat_velX(chan,t)-navSolution.vX(t))*a_x(chan,t)...
    +(sat_velY(chan,t)-navSolution.vY(t))*a_y(chan,t)...
    +(sat_velZ(chan,t)-navSolution.vZ(t))*a_z(chan,t);
            
kf_yerr(chan,t)=(sat_dopp_hz(chan,t)*Lambda_GPS_L1)-rhoDot_pri(chan,t);
        end
    end
end
%%
figure;plot(kf_yerr')
%%
figure;plot(pr_m'-sat_prg_m');hold on
legend('PRN 28','PRN 4','PRN 17','PRN 15','PRN 27','PRN 9','Location','eastoutside')
%% === Convert to UTM coordinate system =============================

% Scenario latitude  is xx.xxxxxxx  N37 49 9.98
% Scenario longitude is -xx.xxxxxxx  W122 28 42.58
% Scenario elevation is 35 meters.
    % lat=[37 49 9.98];
    % long=[-122 -28 -42.58];
    % lat_deg=dms2deg(lat);
    % long_deg=dms2deg(long);
    % h=35;
    
    lat_deg=navSolution.latitude(1);
    lon_deg=navSolution.longitude(1);
    lat=degrees2dms(lat_deg);
    lon=degrees2dms(lon_deg);
    h=navSolution.height(1);


utmstruct = defaultm('utm');
utmstruct.zone =  utmzone(lat_deg, lon_deg);
utmstruct = defaultm(utmstruct);
[utmstruct.latlim,utmstruct.lonlim] = utmzone(utmstruct.zone );
%Choices i of Reference Ellipsoid
%   1. International Ellipsoid 1924
%   2. International Ellipsoid 1967
%   3. World Geodetic System 1972
%   4. Geodetic Reference System 1980
%   5. World Geodetic System 1984

utmstruct.geoid = wgs84Ellipsoid;

% [X, Y] = projfwd(utmstruct,lat_deg,lon_deg);
% Z=h; % geographical to cartesian conversion


% for k=1:1:length(navSolution.X)
%     [navSolution.E(k), ...
%         navSolution.N(k), ...
%         navSolution.U(k)]=cart2utm(navSolution.X(k), navSolution.Y(k), navSolution.Z(k), utmZone);
% end
%% ====== FILTERING =======================================================
moving_avg_factor= 500;
LAT_FILT = movmean(navSolution.latitude,moving_avg_factor);
LON_FILT = movmean(navSolution.longitude,moving_avg_factor);
HEIGH_FILT = movmean(navSolution.height,moving_avg_factor);

X_FILT = movmean(navSolution.X,moving_avg_factor);
Y_FILT = movmean(navSolution.Y,moving_avg_factor);
Z_FILT = movmean(navSolution.Z,moving_avg_factor);

vX_FILT = movmean(navSolution.vX,moving_avg_factor);
vY_FILT = movmean(navSolution.vY,moving_avg_factor);
vZ_FILT = movmean(navSolution.vZ,moving_avg_factor);
%%
general_raw_plot
%%

%---VTL VELOCITY: GNSS SDR plot --------------------------------------
VTL_VEL=figure('Name','velocities and heigh');
subplot(2,2,1);
plot(vtlSolution.rtklibpvt.vX,'.');
hold on;grid on
plot(vtlSolution.kfpvt.vX,'.');
plot(vtlSolution.kferr.vX,'.');
ylabel('vX (m/s)')
xlabel('time U.A.')
ylim([-5 5])
title('Subplot 1: vX ')
legend ('raw RTKlib','raw kf','kferr','Location','east')

subplot(2,2,2);
plot(vtlSolution.rtklibpvt.vY,'.');
hold on;grid on
plot(vtlSolution.kfpvt.vY,'.');
plot(vtlSolution.kferr.vY,'.');
ylabel('vY (m/s)')
xlabel('time U.A.')
ylim([-5 5])
title('Subplot 1: vY ')
legend ('raw RTKlib','raw kf','kferr','Location','east')

subplot(2,2,3);
plot(vtlSolution.rtklibpvt.vZ,'.');
hold on;grid on
plot(vtlSolution.kfpvt.vZ,'.');
plot(vtlSolution.kferr.vZ,'.');
ylabel('vZ (m/s)')
xlabel('time U.A.')
ylim([-5 5])
title('Subplot 1: vZ ')
legend ('raw RTKlib','raw kf','kferr','Location','east')

subplot(2,2,4);
plot(navSolution.RX_time-navSolution.RX_time(1),navSolution.height,'.');
hold on;grid on
plot(navSolution.RX_time-navSolution.RX_time(1),HEIGH_FILT,'r.');
ylabel('HEIGH (m)')
xlabel('time from First FIX in (seconds)')
title('Subplot 4: HEIGH')
legend ('raw',['moving avg:' num2str(moving_avg_factor)],'Location','southeast')

sgtitle('velocities and heigh') 

% --- VTL UTM centered POSITION: GNSS SDR  plot --------------------------------------

VTL_POS=figure('Name','VTL UTM COORD CENTERED IN 1^{ST} POSITION');
subplot(2,2,1);
plot(vtlSolution.rtklibpvt.X-vtlSolution.rtklibpvt.X(1),'.');
hold on;grid on
plot(vtlSolution.kfpvt.X-vtlSolution.kfpvt.X(1),'.');
plot(vtlSolution.kferr.X,'.');
ylabel('X (m)')
xlabel('time U.A.')
ylim([-200 800])
title('Subplot 1: X ')
legend ('raw RTKlib','raw kf','kferr','Location','east')

subplot(2,2,2);
plot(vtlSolution.rtklibpvt.Y-vtlSolution.rtklibpvt.Y(1),'.');
hold on;grid on
plot(vtlSolution.kfpvt.Y-vtlSolution.kfpvt.Y(1),'.');
plot(vtlSolution.kferr.Y,'.');
ylabel('Y (m)')
xlabel('time U.A.')
ylim([-200 50])
title('Subplot 1: Y ')
legend ('raw RTKlib','raw kf','kferr','Location','east')

subplot(2,2,3);
plot(vtlSolution.rtklibpvt.Z-vtlSolution.rtklibpvt.Z(1),'.');
hold on;grid on
plot(vtlSolution.kfpvt.Z-vtlSolution.kfpvt.Z(1),'.');
plot(vtlSolution.kferr.Z,'.');
ylabel('Z (m)')
xlabel('time U.A.')
ylim([-350 50])
title('Subplot 1: Z ')
legend ('raw RTKlib','raw kf','kferr','Location','east')

sgtitle('VTL UTM COORD CENTERED IN 1^{ST} POSITION') 
%%
close all
% --- 'VTL errPV correction --------------------------------------

VTL_errPV=figure('Name','VTL errPV correction');
subplot(2,3,1);
plot(vtlSolution.rtklibpvt.X-vtlSolution.rtklibpvt.X(1),'.');
hold on;grid on
plot(vtlSolution.kfpvt.X-vtlSolution.kfpvt.X(1),'.');
plot(vtlSolution.kferr.X,'.');
plot(vtlSolution.kfpvt.X-vtlSolution.rtklibpvt.X(1)+vtlSolution.kferr.X,'.');
ylabel('X (m)')
xlabel('time U.A.')
ylim([-200 800])
title('Subplot 1: X ')
legend ('raw RTKlib','raw kf','kferr','added err+raw','Location','eastoutside')

subplot(2,3,2);
plot(vtlSolution.rtklibpvt.Y-vtlSolution.rtklibpvt.Y(1),'.');
hold on;grid on
plot(vtlSolution.kfpvt.Y-vtlSolution.kfpvt.Y(1),'.');
plot(vtlSolution.kferr.Y,'.');
plot(vtlSolution.kfpvt.Y-vtlSolution.rtklibpvt.Y(1)+vtlSolution.kferr.Y,'.');
ylabel('Y (m)')
xlabel('time U.A.')
ylim([-200 50])
title('Subplot 1: Y ')
legend ('raw RTKlib','raw kf','kferr','added err+raw','Location','eastoutside')

subplot(2,3,3);
plot(vtlSolution.rtklibpvt.Z-vtlSolution.rtklibpvt.Z(1),'.');
hold on;grid on
plot(vtlSolution.kfpvt.Z-vtlSolution.kfpvt.Z(1),'.');
plot(vtlSolution.kferr.Z,'.');
plot(vtlSolution.kfpvt.Z-vtlSolution.rtklibpvt.Z(1)+vtlSolution.kferr.Z,'.');
ylabel('Z (m)')
xlabel('time U.A.')
ylim([-350 50])
title('Subplot 1: Z ')
legend ('raw RTKlib','raw kf','kferr','added err+raw','Location','eastoutside')

subplot(2,3,4);
plot(vtlSolution.rtklibpvt.vX,'.');
hold on;grid on
plot(vtlSolution.kfpvt.vX,'.');
plot(vtlSolution.kferr.vX,'.');
plot(vtlSolution.kfpvt.vX+vtlSolution.kferr.vX,'.');
ylabel('vX (m/s)')
xlabel('time U.A.')
ylim([-5 5])
title('Subplot 1: vX ')
legend ('raw RTKlib','raw kf','kferr','added err+raw','Location','eastoutside')

subplot(2,3,5);
plot(vtlSolution.rtklibpvt.vY,'.');
hold on;grid on
plot(vtlSolution.kfpvt.vY,'.');
plot(vtlSolution.kferr.vY,'.');
plot(vtlSolution.kfpvt.vY+vtlSolution.kferr.vY,'.');
ylabel('vY (m/s)')
xlabel('time U.A.')
ylim([-5 5])
title('Subplot 1: vY ')
legend ('raw RTKlib','raw kf','kferr','added err+raw','Location','eastoutside')

subplot(2,3,6);
plot(vtlSolution.rtklibpvt.vZ,'.');
hold on;grid on
plot(vtlSolution.kfpvt.vZ,'.');
plot(vtlSolution.kferr.vZ,'.');
plot(vtlSolution.kfpvt.vZ+vtlSolution.kferr.vZ,'.');
ylabel('vZ (m/s)')
xlabel('time U.A.')
ylim([-5 5])
title('Subplot 1: vZ ')
legend ('raw RTKlib','raw kf','kferr','added err+raw','Location','eastoutside')


sgtitle('VTL errPV correction') 
%% ============================================== ==============================================
time_reference_spirent_obs=129780;%s
if(load_observables)
%     figure;plot(Carrier_phase_cycles','.')
%     figure;plot(Pseudorange_m','.')
        %%%
    Carrier_Doppler_hz_sim=zeros(length(refSatData.GPS.SIM_time),6);
    
    for i=1:length(refSatData.GPS.SIM_time)
        Carrier_Doppler_hz_sim(i,1)=refSatData.GPS.series(i).doppler_shift(4);%PRN 28
        Carrier_Doppler_hz_sim(i,2)=refSatData.GPS.series(i).doppler_shift(1);%PRN 4
        Carrier_Doppler_hz_sim(i,3)=refSatData.GPS.series(i).doppler_shift(6);%PRN 17
        Carrier_Doppler_hz_sim(i,4)=refSatData.GPS.series(i).doppler_shift(7);%PRN 15
        Carrier_Doppler_hz_sim(i,5)=refSatData.GPS.series(i).doppler_shift(8);%PRN 27
        Carrier_Doppler_hz_sim(i,6)=refSatData.GPS.series(i).doppler_shift(9);%PRN 9
        
    end
    
    
    Rx_Dopp_all=figure('Name','RX_Carrier_Doppler_hz');plot(RX_time(1,:)-time_reference_spirent_obs, Carrier_Doppler_hz','.')
    xlim([0,140]);
    xlabel('')
    ylabel('Doppler (Hz)')
    xlabel('time from simulation init (seconds)')
    grid on
    hold on
    legend('PRN 28','PRN 4','PRN 17','PRN 15','PRN 27','PRN 9','Location','eastoutside')
    plot(refSatData.GPS.SIM_time/1000, Carrier_Doppler_hz_sim','.')
    legend('PRN 28','PRN 4','PRN 17','PRN 15','PRN 27','PRN 9','Location','eastoutside')
    hold off
    grid on
    
    Rx_Dopp_one=figure('Name','RX_Carrier_Doppler_hz');plot(RX_time(1,:)-time_reference_spirent_obs, Carrier_Doppler_hz(1,:)','.')
    xlim([0,140]);
    ylim([-2340,-2220]);
    xlabel('')
    ylabel('Doppler (Hz)')
    xlabel('time from simulation init (seconds)')
    grid on
    hold on
    legend('PRN 28 GNSS-SDR','Location','eastoutside')
    plot(refSatData.GPS.SIM_time/1000, Carrier_Doppler_hz_sim(:,1)','.','DisplayName','reference')
    hold off
    grid on
end