% =========================================================================
% CONDITIONNEMENT DU CAPTEUR DE POSITION

% FILTRE CAPTEUR DE POSITION

num_pos = 1;

denom_pos = [1/(2*pi*80) 1];

% GAINS ET OFFSET

gain_pos = 1.4925;

offset_pos = -1.6;

% SATURATION

sat_pos_max = 5;

sat_pos_min = 0;

% =========================================================================
% CONDITIONNEMENT DE LA COMMANDE

% FILTRE PWM

R = 5900;
C = 1e-7;

num_com = 1;

denom_com = [R^2*C^2 3*R*C 1];

% GAINS ET OFFSETS

gain_com = 0.88;

offset_com = -2.5;

V_in = [-2.16 -2.2 -2.1 -2 -1.9 -1.8 -1.7 -1.6 -1.5 -1.4 ...
      -1.3 -1.2 -1.1 -1 -0.9 -0.8 -0.7 -0.6 -0.5 -0.4 ...
      -0.3 -0.2 -0.1 0.1 0.2 0.3 0.4 0.5 0.6 0.7 ...
      0.8 0.9 1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 ...
      1.8 1.9 2 2.1 2.14 2.16];

v_out = [-5 -4.96 -4.88 -4.56 -4.36 -4.12 -3.88 -3.64 -3.4 -3.2 ...
      -2.96 -2.72 -2.5 -2.28 -2.04 -1.8 -1.56 -1.36 -1.14 -0.91994 ...
      -0.68 -0.448 -0.27943 0.24001 0.5199 0.64713 0.88001 1.12 1.28 1.52 ...
      1.76 2 2.22 2.44 2.68 2.91 3.15 3.36 3.6 3.84 ...
      4.08 4.32 4.56 4.8 4.93 4.96];

Gain_Ampli_Puissance = polyfit(V_in,v_out, 1);

gain_puis = Gain_Ampli_Puissance(1);

% SATURATION

sat_puis_max = 5;

sat_puis_min = -5;

sat_com_max = 5;

sat_com_min = -5;

% =========================================================================
% CONDITIONNEMENT DU CAPTEUR DE COURANT

% FILTRE CAPTEUR DE COURANT

num_cou = 1;

denom_cou = [1/(2*pi*165) 1];

% GAINS ET OFFSET

gain_cou = 0.716;

offset_cou = 3.44;

% SATURATION

sat_cou_max = 5;

sat_cou_min = 0;

% =========================================================================
% MODÉLISATION DU CAPTEUR DE COURANT

I_bobine = [-2.5461 -2.5183 -2.4699 -2.4141 -2.2674 -2.1483 -2.0323 -1.9165 -1.8013 -1.6982 ...
      -1.5812 -1.4621 -1.3426 -1.2222 -1.1006 -0.9804 -0.8562 -0.7337 -0.6232 -0.49811 ...
      -0.37242 -0.24505 -0.08612 0.09211 0.18404 0.38467 0.51334 0.64063 0.7548 0.8822 ...
      1.009 1.1355 1.2611 1.3853 1.5067 1.6278 1.7462 1.8544 1.9711 2.0824 ...
      2.1992 2.313 2.4243 2.5322 2.58 2.5822];

I_mesure = [-3.44 -3.4 -3.34 -3.23 -3.06 -2.9 -2.74 -2.59 -2.43 -2.29 ...
      -2.14 -1.98 -1.82 -1.66 -1.49 -1.33 -1.16 -0.99823 -0.84804 -0.67945 ...
      -0.51039 -0.33962 -0.1236 0.11875 0.24485 0.52006 0.69683 0.87177 1.03 1.2 ...
      1.38 1.55 1.72 1.9 2.05 2.21 2.38 2.53 2.69 2.84 ...
      3.01 3.16 3.32 3.47 3.54 3.54];

Gain_Ampli_Puissance = polyfit(I_bobine, I_mesure, 1);

gain_mod_cou = Gain_Ampli_Puissance(1);

% =========================================================================
% MODÉLISATION DU CAPTEUR DE POSITION

Tension = [1.17 1.29 1.31 1.48 1.7 1.89 2.11 2.16 2.35 2.65 2.82 2.85 ...
     2.95 3.15 3.21 3.34 3.43 3.5 3.5 3.69 3.73 3.87 4 4.05 4.06 ...
     4.15 4.34 4.45 4.6 4.77 4.85 4.91 4.94 4.94 4.95 4.95 4.95 4.96];

Distance = [15.9 13.9 13.7 11.9 9.9 8.7 7.6 7.5 6.8 5.8 5.4 5 ...
     4.8 4.6 4.4 4.2 4 3.8 4 3.6 3.5 3.4 3.1 3 3 ...
     2.8 2.6 2.4 2.1 1.9 1.7 1.5 0 0.2 0.4 0.7 1.3 1] * 10^-3;

point_init = 6;
point_final = 32;

distance_selon_tension = polyfit(Tension(1:point_final), Distance(1:point_final), 3);
tension_selon_distance = polyfit(Distance(1:point_final), Tension(1:point_final), 3);

sat_mod_pos_max = 5;

sat_mod_pos_min = 0;



% =========================================================================
% MODÉLISATION ARDUINO

% ACQUISITION DES DONNÉES

freq_adc = 6000; % Hz

per_adc = 1/freq_adc; % s

res_adc = 10; % Nombre de bits

% CONVERSION ANALOGIQUE

freq_pwm = 15625; % Hz

per_pwm = 1/freq_pwm; % s

res_dac = 10; % bits

% RÉGULATION COURANT

G_cou = tf(2.1309*[0.0037003 1], [0.0037003 0]);
Gz_cou = c2d(G_cou, 1/600, 'tustin');

[num_pid_cou, denom_pid_cou] = tfdata(Gz_cou, 'v');

% RÉGULATION POSITION
G_pos = tf(-6.83293481052641*1023/5, [1 0]);
Gz_pos = c2d(G_pos, 1/600, 'tustin');

[num_pid_pos, denom_pid_pos] = tfdata(Gz_pos, 'v');


% =========================================================================
% MODÉLISATION ACTIONNEUR LINÉAIRE

sat_act_max = 5;

sat_act_min = 0;

ref_pos_act = 10;

rb = 1.1745 + 2.349;

load("table complete.mat")
dL_table = LUT_Table{:,6};
dPhi_table = LUT_Table{:,7};
kb_table = LUT_Table{:,5};
Lb_table = LUT_Table{:,4};
x_table = LUT_Table{:,2};

% =========================================================================
% PARAMÈTRES DE SIMULATION INHÉRENTS À SIMULINK

step_time = 1/750000;
