% Script Matlab Reg_courant_RL_H26m_ADAPTE.m
% Adapté à partir du template Reg_courant_RL_H26m.m
% Paramètres mis à jour avec les données du vrai montage

clear all
close all
clc

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% VARIABLES DU PROCÉDÉ (Circuit RL, amplificateur, capteur de courant)

% -------------------------------------------------------------------------
% Inductance et résistance du circuit
% -------------------------------------------------------------------------

Lel = 0.0002797;                 % H
Rel = 1.1745 + 2.349;            % Ohm

% Constante de temps électrique
Tel = Lel / Rel;

% Gain statique FT du circuit RL
Kel = 1 / Rel;

% -------------------------------------------------------------------------
% Choix du pas de calcul Ts
% -------------------------------------------------------------------------

nTsTel = 40;                     % Ts = Tel/40
Ts = Tel / nTsTel;

% -------------------------------------------------------------------------
% Gain ampli de puissance réel
% -------------------------------------------------------------------------

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

Gain_Ampli_Puissance = polyfit(V_in, v_out, 1);
Kamp = Gain_Ampli_Puissance(1);     % sans unité

% -------------------------------------------------------------------------
% Gain réel du capteur de courant
% -------------------------------------------------------------------------

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

Gain_Capteur_Courant = polyfit(I_bobine, I_mesure, 1);
Kc = Gain_Capteur_Courant(1);       % V/A

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RÉGLAGE DES ÉCHELLES DES OSCILLOSCOPES

Ian = 0.5;                           % A
Vmax = abs(Kamp * 5);               % tension max approximative atteignable
Imax = Ian;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GÉNÉRATEURS DE CONSIGNES DE COURANT POUR ESSAIS DU RÉGULATEUR

Ntau = 6;
Tperturbcourant = 4 * ceil(Ntau * Tel / Ts);
PulseWidth = Tperturbcourant / 2;
TimeSpanScope = 2 * Tperturbcourant * Ts;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMÈTRES DES RÉGULATEURS DE COURANT

% Limiteur du PI de courant
limVampsup = 5;
limVampinf = -5;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMÈTRES RÉGULATEURS DE COURANT DISCRETS

nTechTel_voulu = 10;

diviseurs = find(mod(nTsTel,1:nTsTel) == 0);
[~, idx] = min(abs(diviseurs - nTechTel_voulu));
nTechTel = diviseurs(idx);

Tech = Tel / nTechTel;

% Vérification : rapport entier
NTechTs = round(Tech / Ts);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TEST REJET TENSION DE PERTURBATION EN SÉRIE AVEC CIRCUIT RL

nc = 10;
fperturbation = 1 / (2*pi*nc*Tel);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AFFICHAGE RAPIDE

disp('--- Paramètres utilisés ---')
disp(['Lel = ', num2str(Lel), ' H'])
disp(['Rel = ', num2str(Rel), ' Ohm'])
disp(['Tel = ', num2str(Tel), ' s'])
disp(['Ts = ', num2str(Ts), ' s'])
disp(['Tech = ', num2str(Tech), ' s'])
disp(['Kamp = ', num2str(Kamp)])
disp(['Kc = ', num2str(Kc), ' V/A'])
disp(['Vmax = ', num2str(Vmax), ' V'])
disp(['Imax = ', num2str(Imax), ' A'])