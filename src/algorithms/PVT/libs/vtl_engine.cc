/*!
 * \file vtl_engine.h
 * \brief Class that implements a Vector Tracking Loop (VTL) Kalman filter engine
 * \author Javier Arribas, 2022. jarribas(at)cttc.es
 *
 * -----------------------------------------------------------------------------
 *
 * GNSS-SDR is a Global Navigation Satellite System software-defined receiver.
 * This file is part of GNSS-SDR.
 *
 * Copyright (C) 2010-2022  (see AUTHORS file for a list of contributors)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * -----------------------------------------------------------------------------
 */

#include "vtl_engine.h"
#include "iostream"

using namespace std;

Vtl_Engine::Vtl_Engine()
{
}

Vtl_Engine::~Vtl_Engine()
{
}

bool Vtl_Engine::vtl_loop(Vtl_Data new_data, double PVT_out[6])
{
    //TODO: Implement main VTL loop here
    using arma::as_scalar;

    // ################## Kalman filter initialization ######################################
    // covariances (static)
    kf_P_x  = arma::eye(8, 8); //TODO: use a real value.
    kf_x    = arma::zeros(8, 1);
    kf_R    = arma::zeros(2*new_data.sat_number, 2*new_data.sat_number);
    double kf_dt=1e-1;
    kf_Q = arma::zeros(8, 8);

    kf_F = arma::zeros(8, 8);
    kf_F(0, 0) = 1.0; kf_F(0, 3) = kf_dt;
    kf_F(1, 1) = 1.0; kf_F(1, 4) = kf_dt;
    kf_F(2, 2) = 1.0; kf_F(2, 5) = kf_dt;
    kf_F(3, 3) = 1.0; 
    kf_F(4, 4) = 1.0; 
    kf_F(5, 5) = 1.0;
    kf_F(6, 6) = 1.0; kf_F(6, 7) = kf_dt;
    kf_F(7, 7) = 1.0;

    kf_H = arma::zeros(8, 2*new_data.sat_number);
    kf_x = arma::zeros(8, 1);
    kf_y = arma::zeros(2*new_data.sat_number, 1);
    kf_yerr = arma::zeros(2*new_data.sat_number, 1);
    kf_xerr = arma::zeros(8, 1);
    kf_S = arma::zeros(2*new_data.sat_number, 2*new_data.sat_number); // kf_P_y innovation covariance matrix
    
    // ################## Kalman Tracking ######################################
    static uint32_t  counter=0; //counter  
    counter=counter+1; //uint64_t 
    cout << "counter" << counter;

    if(counter<3000){ //
        // receiver solution from rtklib_solver
        kf_x(0)=new_data.rx_p(0);
        kf_x(1)=new_data.rx_p(1);
        kf_x(2)=new_data.rx_p(2);
        kf_x(3)=new_data.rx_v(0);
        kf_x(4)=new_data.rx_v(1);
        kf_x(5)=new_data.rx_v(2);
        kf_x(6)=new_data.rx_dts(0); 
        kf_x(7)=new_data.rx_dts(1);
    }
    else{
        kf_x=new_data.kf_state;
        kf_P_x=new_data.kf_P;
    }

    for (int32_t i = 0; i < 8; i++) // State error Covariance Matrix Q (PVT)
    {
        // It is diagonal 8x8 matrix 
        kf_Q(i, i) = new_data.rx_pvt_var(i); //careful, values for V and T could not be adecuate.
    }

    // Kalman state prediction (time update)
    // kf_x.print(" KF RTKlib STATE");
    new_data.kf_state=kf_x; 
    kf_x = kf_F * kf_x;                        // state prediction
    kf_P_x= kf_F * kf_P_x * kf_F.t() + kf_Q;  // state error covariance prediction
    //from error state variables to variables
    // From state variables definition
    // TODO: cast to type properly
    x_u=kf_x(0);
    y_u=kf_x(1);
    z_u=kf_x(2);
    xDot_u=kf_x(3);
    yDot_u=kf_x(4);
    zDot_u=kf_x(5);
    cdeltat_u=kf_x(6)*SPEED_OF_LIGHT_M_S;
    cdeltatDot_u=kf_x(7)*SPEED_OF_LIGHT_M_S;

    d = arma::zeros(new_data.sat_number, 1);
    rho_pri = arma::zeros(new_data.sat_number, 1);
    rhoDot_pri = arma::zeros(new_data.sat_number, 1);
    a_x = arma::zeros(new_data.sat_number, 1);
    a_y = arma::zeros(new_data.sat_number, 1);
    a_z = arma::zeros(new_data.sat_number, 1);
    for (int32_t i = 0; i < new_data.sat_number; i++) //neccesary quantities
    {
        //d(i) is the distance sat(i) to receiver
        d(i)=(new_data.sat_p(i, 0)-x_u)*(new_data.sat_p(i, 0)-x_u);
        d(i)=d(i)+(new_data.sat_p(i, 1)-y_u)*(new_data.sat_p(i, 1)-y_u);
        d(i)=d(i)+(new_data.sat_p(i, 2)-z_u)*(new_data.sat_p(i, 2)-z_u);
        d(i)=sqrt(d(i)); 

        //compute pseudorange estimation 
        rho_pri(i)=d(i)+cdeltat_u;
        //compute LOS sat-receiver vector components 
        a_x(i)=-(new_data.sat_p(i, 0)-x_u)/d(i);
        a_y(i)=-(new_data.sat_p(i, 1)-y_u)/d(i);
        a_z(i)=-(new_data.sat_p(i, 2)-z_u)/d(i);
        new_data.sat_LOS(i,0)=a_x(i);
        new_data.sat_LOS(i,1)=a_y(i);
        new_data.sat_LOS(i,2)=a_z(i);
        //compute pseudorange rate estimation
        rhoDot_pri(i)=(new_data.sat_v(i, 0)-xDot_u)*a_x(i)+(new_data.sat_v(i, 1)-yDot_u)*a_y(i)+(new_data.sat_v(i, 2)-zDot_u)*a_z(i)+cdeltatDot_u;
    }

    kf_H = arma::zeros(2*new_data.sat_number,8);

    for (int32_t i = 0; i < new_data.sat_number; i++) // Measurement matrix H assembling
    {
        // It has 8 columns (8 states) and 2*NSat rows (NSat psudorange error;NSat pseudo range rate error) 
        kf_H(i, 0) = a_x(i); kf_H(i, 1) = a_y(i); kf_H(i, 2) = a_z(i); kf_H(i, 6) = 1.0;
        kf_H(i+new_data.sat_number, 3) = a_x(i); kf_H(i+new_data.sat_number, 4) = a_y(i); kf_H(i+new_data.sat_number, 5) = a_z(i); kf_H(i+new_data.sat_number, 7) = 1.0;
    }
    // Kalman estimation (measurement update)
   for (int32_t i = 0; i < new_data.sat_number; i++) // Measurement vector
   {
        //kf_y(i) = new_data.pr_m(i); // i-Satellite 
        //kf_y(i+new_data.sat_number) = rhoDot_pri(i)/Lambda_GPS_L1; // i-Satellite
        kf_yerr(i)=new_data.pr_m(i)-rho_pri(i);//-0.000157*SPEED_OF_LIGHT_M_S;
        kf_yerr(i+new_data.sat_number)=(new_data.doppler_hz(i)*Lambda_GPS_L1+cdeltatDot_u)-rhoDot_pri(i);

   }
    kf_yerr.print("KF measurement vector difference");

     // DOUBLES DIFFERENCES
    // kf_yerr = arma::zeros(2*new_data.sat_number, 1);
    // for (int32_t i = 1; i < new_data.sat_number; i++) // Measurement vector
    // {
    //     kf_y(i)=new_data.pr_m(i)-new_data.pr_m(i-1);
    //     kf_yerr(i)=kf_y(i)-(rho_pri(i)+rho_pri(i-1));
    //     kf_y(i+new_data.sat_number)=(rhoDot_pri(i)-rhoDot_pri(i-1))/Lambda_GPS_L1;
    //     kf_yerr(i+new_data.sat_number)=kf_y(i+new_data.sat_number)-(new_data.doppler_hz(i)-new_data.doppler_hz(i-1));
    // }
    // kf_yerr.print("DOUBLES DIFFERENCES");
    
    for (int32_t i = 0; i < new_data.sat_number; i++) // Measurement error Covariance Matrix R assembling
    {
        // It is diagonal 2*NSatellite x 2*NSatellite (NSat psudorange error;NSat pseudo range rate error) 
        kf_R(i, i) = 20.0; //TODO: fill with real values.
        kf_R(i+new_data.sat_number, i+new_data.sat_number) = 10.0;
    }

    // Kalman filter update step
    kf_S = kf_H * kf_P_x* kf_H.t() + kf_R;                      // innovation covariance matrix (S)
    kf_K = (kf_P_x * kf_H.t()) * arma::inv(kf_S);               // Kalman gain  
    kf_xerr = kf_K * (kf_yerr);                                 // Error state estimation
    kf_x = kf_x + kf_xerr;                                      // updated state estimation (a priori + error)
    kf_P_x = (arma::eye(size(kf_P_x)) - kf_K * kf_H) * kf_P_x;  // update state estimation error covariance matrix
    new_data.kf_state=kf_x; //updated state estimation
    new_data.kf_P=kf_P_x; //update state estimation error covariance 
    // States related tu USER clock adjust from m/s to s (by /SPEED_OF_LIGHT_M_S)
    PVT_out[0]=kf_x(0);
    PVT_out[1]=kf_x(1);
    PVT_out[2]=kf_x(2);
    PVT_out[3]=kf_x(3);
    PVT_out[4]=kf_x(4);
    PVT_out[5]=kf_x(5);
    // kf_x(6) =kf_x(6) /SPEED_OF_LIGHT_M_S;
    // kf_x(7) =kf_x(7) /SPEED_OF_LIGHT_M_S;

    kf_x(6)=cdeltat_u/SPEED_OF_LIGHT_M_S;
    kf_x(7)=cdeltatDot_u/SPEED_OF_LIGHT_M_S; 

    //new_data.pr_res.print(" pr RESIDUALS");
    //!new_data.kf_state.print(" KF RTKlib STATE");
    //!cout << " KF posteriori STATE diference" << kf_x-new_data.kf_state;
    //!cout << " KF posteriori STATE diference %1" << (kf_x-new_data.kf_state)/new_data.kf_state;

//     // ################## Geometric Transformation ######################################

//     // x_u=kf_x(0);
//     // y_u=kf_x(1);
//     // z_u=kf_x(2);
//     // xDot_u=kf_x(3);
//     // yDot_u=kf_x(4);
//     // zDot_u=kf_x(5);
//     // cdeltat_u=kf_x(6)*SPEED_OF_LIGHT_M_S;
//     // cdeltatDot_u=kf_x(7)*SPEED_OF_LIGHT_M_S;

   for (int32_t i = 0; i < new_data.sat_number; i++) //neccesary quantities
    {
        //d(i) is the distance sat(i) to receiver
        d(i)=(new_data.sat_p(i, 0)-kf_x(0))*(new_data.sat_p(i, 0)-kf_x(0));
        d(i)=d(i)+(new_data.sat_p(i, 1)-kf_x(1))*(new_data.sat_p(i, 1)-kf_x(1));
        d(i)=d(i)+(new_data.sat_p(i, 2)-kf_x(2))*(new_data.sat_p(i, 2)-kf_x(2));
        d(i)=sqrt(d(i)); 

        //compute pseudorange estimation 
        rho_pri(i)=d(i)+kf_x(6)*SPEED_OF_LIGHT_M_S;
        //compute LOS sat-receiver vector components 
        a_x(i)=-(new_data.sat_p(i, 0)-kf_x(0))/d(i);
        a_y(i)=-(new_data.sat_p(i, 1)-kf_x(1))/d(i);
        a_z(i)=-(new_data.sat_p(i, 2)-kf_x(2))/d(i);
        //compute pseudorange rate estimation
        rhoDot_pri(i)=(new_data.sat_v(i, 0)-kf_x(3))*a_x(i)+(new_data.sat_v(i, 1)-kf_x(4))*a_y(i)+(new_data.sat_v(i, 2)-kf_x(5))*a_z(i)+kf_x(7)*SPEED_OF_LIGHT_M_S;
    }

    kf_H = arma::zeros(2*new_data.sat_number,8);

    for (int32_t i = 0; i < new_data.sat_number; i++) // Measurement matrix H assembling
    {
        // It has 8 columns (8 states) and 2*NSat rows (NSat psudorange error;NSat pseudo range rate error) 
        kf_H(i, 0) = a_x(i); kf_H(i, 1) = a_y(i); kf_H(i, 2) = a_z(i); kf_H(i, 6) = 1.0;
        kf_H(i+new_data.sat_number, 3) = a_x(i); kf_H(i+new_data.sat_number, 4) = a_y(i); kf_H(i+new_data.sat_number, 5) = a_z(i); kf_H(i+new_data.sat_number, 7) = 1.0;
    }

//  Re-calculate error measurement vector with the most recent data available: kf_delta_y=kf_H*kf_delta_x 
    kf_yerr=kf_H*kf_xerr;
//  Filtered pseudorange error measurement (in m) AND Filtered Doppler shift measurements (in Hz):

   for (int32_t i = 0; i < new_data.sat_number; i++) // Measurement vector
   {

        rho_pri(i)=new_data.pr_m(i)-kf_yerr(i); // now filtered
        rhoDot_pri(i)=(new_data.doppler_hz(i)*Lambda_GPS_L1+cdeltatDot_u)-kf_yerr(i+new_data.sat_number); // now filtered
        // TO DO: convert rhoDot_pri to doppler shift!
        // Doppler shift defined as pseudorange rate measurement divided by the negative of carrier wavelength.
        rhoDot_pri(i)=-rhoDot_pri(i)/Lambda_GPS_L1; 
   }
    //TODO: Fill the tracking commands outputs
    // Notice: keep the same satellite order as in the Vtl_Data matrices
    // sample code
    TrackingCmd trk_cmd;
    trk_cmd.carrier_freq_hz = 0;
    trk_cmd.carrier_freq_rate_hz_s = 0;
    trk_cmd.code_freq_chips = 0;
    trk_cmd.enable_carrier_nco_cmd = true;
    trk_cmd.enable_code_nco_cmd = true;
    trk_cmd.sample_counter = new_data.sample_counter;
    trk_cmd_outs.push_back(trk_cmd);
    new_data.debug_print();
    return true;
}

void Vtl_Engine::reset()
{
    //TODO
}

void Vtl_Engine::debug_print()
{
    //TODO
}

void Vtl_Engine::configure(Vtl_Conf config_)
{
    config = config_;
    //TODO: initialize internal variables
}