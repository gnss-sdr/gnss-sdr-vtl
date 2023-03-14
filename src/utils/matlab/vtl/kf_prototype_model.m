%% vtl KF
load rocket_model_dynamics.mat
%%
sat_number=6; % limit by csv?
%% ################## Kalman filter initialization ######################################
state_number=9;
% covariances (static)
kf_P_x  = eye(state_number); %TODO: use a real value.
kf_x    = zeros(state_number, 1);
kf_R    = zeros(2*sat_number, 2*sat_number);
kf_dt=0.05;
% kf_F = eye(state_number, state_number);
% kf_F(1, 4) = kf_dt;
% kf_F(2, 5) = kf_dt;
% kf_F(3, 6) = kf_dt;
% kf_F(7, 8) = kf_dt;

kf_F=[      1     0     0     kf_dt     0           0     0     0       0
            0     1     0     0         kf_dt       0     0     0       0
            0     0     1     0         0           kf_dt 0     0       0
            0     0     0     1         0           0     0     0       0
            0     0     0     0         1           0     0     0       0
            0     0     0     0         0           1     0     0       0
            0     0     0     0         0           0     1     kf_dt   kf_dt^2/2
            0     0     0     0         0           0     0     1       kf_dt
            0       0   0       0       0           0       0   0       1];

% kf_F=[      1     0     0     kf_dt     0           0     0     0
%             0     1     0     0         kf_dt       0     0     0
%             0     0     1     0         0           kf_dt 0     0
%             0     0     0     1         0           0     0     0
%             0     0     0     0         1           0     0     0
%             0     0     0     0         0           1     0     0
%             0     0     0     0         0           0     1     kf_dt
%             0     0     0     0         0           0     0     1];
%  
kf_H = zeros(2*sat_number,state_number);
kf_y = zeros(2*sat_number, 1);
kf_yerr = zeros(2*sat_number, 1);
% kf_xerr = zeros(8, 1);
kf_S = zeros(2*sat_number, 2*sat_number); % kf_P_y innovation covariance matrix

%% pre-allocate for speed     
d = zeros(sat_number, 1);
rho_pri = zeros(sat_number, 1);
rhoDot_pri = zeros(sat_number, 1);
a_x = zeros(sat_number, 1);
a_y = zeros(sat_number, 1);
a_z = zeros(sat_number, 1);
c_pr_m=zeros(sat_number,length(navSolution.RX_time));

pr_m_filt=zeros(sat_number,length(navSolution.RX_time));
rhoDot_pri_filt=zeros(sat_number,length(navSolution.RX_time));
sat_dopp_hz_filt=zeros(sat_number,length(navSolution.RX_time));

%% ################## Kalman Tracking ######################################
% receiver solution from rtklib_solver
index=0;
modelflag=0;
t_from_lunch=0;
for t=2:length(navSolution.RX_time)

    index=index+1;
    %% State error Covariance Matrix Q (PVT) and R (MEASUREMENTS)
    if (index < point_of_closure)
        %% State error Covariance Matrix Q (PVT)
        kf_Q = blkdiag(posx_var,posy_var,posz_var,velx_var,vely_var,velz_var,clk_bias_var,clk_drift_var,clk_d_drift_var);
        %%

        % Measurement error Covariance Matrix R assembling
        kf_R = blkdiag(eye(sat_number)*pr_var,eye(sat_number)*pr_dot_var);

    else
        kf_Q = blkdiag(posx_var,posy_var,posz_var,velx_var,vely_var,velz_var,clk_bias_var,clk_drift_var,clk_d_drift_var);
        for chan=1:sat_number           
            kf_R(chan,chan) = pr_var*sat_CN0_dBhz(chan,t)/200;
            kf_R(chan+sat_number,chan+sat_number)= pr_dot_var*sat_CN0_dBhz(chan,t)/200;
        end
    end

    if(~modelflag)
        clear x_u y_u z_u xDot_u yDot_u zDot_u cdeltatDot_u cdeltatDot_u_g cdeltat_u_g
        if (index < point_of_closure)
            disp('one step')
            kf_x(1,t) = navSolution.X(t);
            kf_x(2,t) = navSolution.Y(t);
            kf_x(3,t) = navSolution.Z(t);
            kf_x(4,t) = navSolution.vX(t);
            kf_x(5,t) = navSolution.vY(t);
            kf_x(6,t) = navSolution.vZ(t);
            kf_x(7,t) = clk_bias_s(t)*SPEED_OF_LIGHT_M_S;
            kf_x(8,t) = clk_drift(t)*SPEED_OF_LIGHT_M_S;%new_data.rx_dts(1);
            kf_x(9,t) = 1.0;

            x_u=kf_x(1,t);
            y_u=kf_x(2,t);
            z_u=kf_x(3,t);
            xDot_u=kf_x(4,t);
            yDot_u=kf_x(5,t);
            zDot_u=kf_x(6,t);
            cdeltat_u(t)=kf_x(7,t);
            cdeltatDot_u=kf_x(8,t);

            % Kalman state prediction (time update)
            kf_P_x  = eye(state_number)*100; %TODO: use a real value.
            kf_xpri(:,t) = kf_F * (kf_x(:,t)-kf_x(:,t-1));% state prediction
            kf_P_x= kf_F * kf_P_x * kf_F' + kf_Q;% state error covariance prediction
        else
            disp('feedback')
            x_u=corr_kf_state(1,t-1);
            y_u=corr_kf_state(2,t-1);
            z_u=corr_kf_state(3,t-1);
            xDot_u=corr_kf_state(4,t-1);
            yDot_u=corr_kf_state(5,t-1);
            zDot_u=corr_kf_state(6,t-1);
            cdeltat_u(t)=corr_kf_state(7,t-1);
            cdeltatDot_u=corr_kf_state(8,t-1);

            % Kalman state prediction (time update)
            kf_P_x= kf_F * kf_P_x * kf_F' + kf_Q;% state error covariance prediction
        end
    else
            disp('MODEL')
            t_from_lunch=t_from_lunch+3;
            if(t_from_lunch>length(rocket_model_dynamics.vX))
                t_from_lunch=length(rocket_model_dynamics.vX);
            end
            kf_x(1,t) = rocket_model_dynamics.X(t_from_lunch);
            kf_x(2,t) = rocket_model_dynamics.Y(t_from_lunch);
            kf_x(3,t) = rocket_model_dynamics.Z(t_from_lunch);
            kf_x(4,t) = rocket_model_dynamics.vX(t_from_lunch);
            kf_x(5,t) = rocket_model_dynamics.vY(t_from_lunch);
            kf_x(6,t) = rocket_model_dynamics.vZ(t_from_lunch);
            kf_x(7,t) = clk_bias_s(t)*SPEED_OF_LIGHT_M_S;
            kf_x(8,t) = clk_drift(t)*SPEED_OF_LIGHT_M_S;%new_data.rx_dts(1);
            kf_x(9,t) = 1.0;

            x_u=kf_x(1,t);
            y_u=kf_x(2,t);
            z_u=kf_x(3,t);
            xDot_u=kf_x(4,t);
            yDot_u=kf_x(5,t);
            zDot_u=kf_x(6,t);
            cdeltat_u(t)=kf_x(7,t);
            cdeltatDot_u=kf_x(8,t);

            % Kalman state prediction (time update)
            kf_P_x  = eye(state_number)*1; %TODO: use a real value.
            kf_xpri(:,t) = kf_F * (kf_x(:,t)-kf_x(:,t-1));% state prediction
            kf_P_x= kf_F * kf_P_x * kf_F' + kf_Q;% state error covariance prediction
    end

    for chan=1:sat_number %neccesary quantities
        d(chan)=(sat_posX_m(chan,t)-x_u)^2;
        d(chan)=d(chan)+(sat_posY_m(chan,t)-y_u)^2;
        d(chan)=d(chan)+(sat_posZ_m(chan,t)-z_u)^2;
        d(chan)=sqrt(d(chan));

        c_pr_m(chan,t)=d(chan)+cdeltat_u(t);

        a_x(chan,t)=-(sat_posX_m(chan,t)-x_u)/d(chan);
        a_y(chan,t)=-(sat_posY_m(chan,t)-y_u)/d(chan);
        a_z(chan,t)=-(sat_posZ_m(chan,t)-z_u)/d(chan);

        rhoDot_pri(chan,t)=(sat_velX(chan,t)-xDot_u)*a_x(chan,t)...
            +(sat_velY(chan,t)-yDot_u)*a_y(chan,t)...
            +(sat_velZ(chan,t)-zDot_u)*a_z(chan,t);
    end


    for chan=1:sat_number % Measurement matrix H assembling
        % It has st_nmbr columns (st_nmbr states) and 2*NSat rows (NSat psudorange error;NSat pseudo range rate error)
        kf_H(chan, 1) = a_x(chan,t); kf_H(chan, 2) = a_y(chan,t); kf_H(chan, 3) = a_z(chan,t); kf_H(chan, 7) = 1.0;
        kf_H(chan+sat_number, 4) = a_x(chan,t); kf_H(chan+sat_number, 5) = a_y(chan,t); kf_H(chan+sat_number, 6) = a_z(chan,t); kf_H(chan+sat_number, 8) = 1.0;
    end

    %     unobsv(t) = length(kf_F) - rank(obsv(kf_F,kf_H));
    % !!!! Limitaciones
    % obsv no se recomienda para el diseño de control, ya que calcular el rango de la matriz de observabilidad
    % no se recomienda para las pruebas de observabilidad. Ob será numéricamente singular para la mayoría de los
    % sistemas con más de unos cuantos estados. Este hecho está bien documentado en la sección III de [1].

    % Kalman stimation (measurement update)
    for chan=1:sat_number % Measurement matrix H assembling
        kf_yerr(chan,t)=c_pr_m(chan,t)-sat_prg_m(chan,t);
        if (t<length(navSolution.RX_time)-point_of_closure)
            kf_yerr(chan+sat_number,t)=(sat_dopp_hz(chan,t)*Lambda_GPS_L1)-rhoDot_pri(chan,t);
        else
            kf_yerr(chan+sat_number,t)=(sat_dopp_hz(chan,t)*Lambda_GPS_L1+cdeltatDot_u)-rhoDot_pri(chan,t);
        end
    end

% pause
    % DOUBLES DIFFERENCES
    % kf_yerr = zeros(2*sat_number, 1);
    % for (int32_t i = 1; i < sat_number; i++) % Measurement vector
    % {
    %     kf_y(i)=new_data.pr_m(i)-new_data.pr_m(i-1);
    %     kf_yerr(i)=kf_y(i)-(rho_pri(i)+rho_pri(i-1));
    %     kf_y(i+sat_number)=(rhoDot_pri(i)-rhoDot_pri(i-1))/Lambda_GPS_L1;
    %     kf_yerr(i+sat_number)=kf_y(i+sat_number)-(new_data.doppler_hz(i)-new_data.doppler_hz(i-1));
    % }
    % kf_yerr.print("DOUBLES DIFFERENCES");

    % Kalman filter update step
    kf_S = kf_H * kf_P_x* kf_H' + kf_R; % innovation covariance matrix (S)
    kf_K = (kf_P_x * kf_H') * inv(kf_S); % Kalman gain
    kf_xerr(:,t) = kf_K * (kf_yerr(:,t)); % Error state estimation
    kf_P_x = (eye(length(kf_P_x)) - kf_K * kf_H) * kf_P_x; % update state estimation error covariance matrix

    if (index<point_of_closure)
        corr_kf_state(:,t)=kf_xpri(:,t)-kf_xerr(:,t)+kf_x(:,t); %updated state estimation
    else
        corr_kf_state(:,t)=corr_kf_state(:,t-1)-kf_xerr(:,t); %updated state estimation
    end

    if(modelflag)
        corr_kf_state(:,t)=kf_xpri(:,t)-kf_xerr(:,t)+kf_x(:,t); %updated state estimation
    end
if(sum(abs([xDot_u;yDot_u;zDot_u])>100)>1)
    modelflag=1;
end
    %%  ################## Geometric Transformation ######################################


    x_u=corr_kf_state(1,t);
    y_u=corr_kf_state(2,t);
    z_u=corr_kf_state(3,t);
    xDot_u=corr_kf_state(4,t);
    yDot_u=corr_kf_state(5,t);
    zDot_u=corr_kf_state(6,t);
    cdeltat_u_g=corr_kf_state(7,t);
    cdeltatDot_u_g=corr_kf_state(8,t);

    for chan=1:sat_number %neccesary quantities
        d(chan)=(sat_posX_m(chan,t)-x_u)^2;
        d(chan)=d(chan)+(sat_posY_m(chan,t)-y_u)^2;
        d(chan)=d(chan)+(sat_posZ_m(chan,t)-z_u)^2;
        d(chan)=sqrt(d(chan));

        c_pr_m(chan,t)=d(chan)+cdeltat_u_g;

        a_x(chan,t)=-(sat_posX_m(chan,t)-x_u)/d(chan);
        a_y(chan,t)=-(sat_posY_m(chan,t)-y_u)/d(chan);
        a_z(chan,t)=-(sat_posZ_m(chan,t)-z_u)/d(chan);

        rhoDot_pri(chan,t)=(sat_velX(chan,t)-xDot_u)*a_x(chan,t)...
            +(sat_velY(chan,t)-yDot_u)*a_y(chan,t)...
            +(sat_velZ(chan,t)-zDot_u)*a_z(chan,t);
    end

    kf_H = zeros(2*sat_number,state_number);

    for chan=1:sat_number % Measurement matrix H assembling
        % It has st_nmbr columns (st_nmbr states) and 2*NSat rows (NSat psudorange error;NSat pseudo range rate error)
        kf_H(chan, 1) = a_x(chan,t); kf_H(chan, 2) = a_y(chan,t); kf_H(chan, 3) = a_z(chan,t); kf_H(chan, 7) = 1.0;
        kf_H(chan+sat_number, 4) = a_x(chan,t); kf_H(chan+sat_number, 5) = a_y(chan,t); kf_H(chan+sat_number, 6) = a_z(chan,t); kf_H(chan+sat_number, 8) = 1.0;
    end

    %  Re-calculate error measurement vector with the most recent data available: kf_delta_y=kf_H*kf_delta_x
    kf_yerr_g=kf_H*kf_xerr;
    disp("kf_yerr_g:")
    disp(kf_yerr_g(:,t))
    disp('zDot_u:')
    disp(zDot_u)
    %  Filtered pseudorange error measurement (in m) AND Filtered Doppler shift measurements (in Hz):
    for chan=1:sat_number % Measurement vector
        pr_m_filt(chan,t)=sat_prg_m(chan,t)+kf_yerr_g(chan,t);% now filtered
        rhoDot_pri_filt(chan,t)=(sat_dopp_hz(chan,t)*Lambda_GPS_L1+corr_kf_state(8,t))-kf_yerr_g(chan+sat_number,t);
        %convert rhoDot_pri to doppler shift!
        % d_dt_clk_drift=(corr_kf_state(8,t)-corr_kf_state(8,t-1));
        % d_dt_clk_drift=0;
        sat_dopp_hz_filt(chan,t)=(rhoDot_pri_filt(chan,t)-corr_kf_state(8,t))/Lambda_GPS_L1;
        err_carrier_phase_rads_filt(chan,t) = trapz(kf_yerr_g(chan+sat_number,1:t)/Lambda_GPS_L1)*2*kf_dt;
        carrier_freq_hz =GPS_L1_freq_hz+sat_dopp_hz_filt(chan,t);
        %       carrier_freq_rate_hz_s = 0;
        err_code_phase_chips(chan,t) = (kf_yerr_g(chan,t))/SPEED_OF_LIGHT_M_S*1023e3;
    end

end