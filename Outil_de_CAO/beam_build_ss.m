close all;
tic();
%% Temporaire
sat_proc_max = 1;
sat_proc_min = -1;

%% masse mesurée en entrée du simulink
bloc_entree_masse = 'Simulation_balancenew2024/Masse (kg)';
block_value_str = get_param(bloc_entree_masse, 'Value');
masse_simulink = str2double(block_value_str);

%% Paramètres de La poutre et du matériau
b = 7.1e-2;      % Base 6 cm (selon ton code: 7.1 cm)
h = 1.5e-3;      % Hauteur 1.56 mm (1.5 mm ici)
L = 24.3e-2;     % Longueur 24.6 cm (24.3 cm ici)
E = 24e9;        % Module de Young 24 GPa
dens = 1850;     % Densité Kg/m^3
mu = dens*b*h;   % Masse linéique kg/m (rho * A_ss)
A_b = b*h;       % Aire de la section
J = b*h^3/12;    % Moment d'inertie (I)

%% Paramètres de modélisation eléments finis
ne = 20;         % Nombre d'éléments spatiaux
le = L / ne;     % Longueur d'un élément (l_b)
nnodes = ne + 1; % Nombre de noeuds
ndof = 2 * nnodes; % 2 degrés de liberté par noeud (déplacement transversal et rotation)

faire_fft = false;
plot_position = false;

%% Paramètres des masses et forces
pos_actionneur_et_masse = 0.146; % Position en mètre
masse_bobine_et_plaque = 40/1000;
masse = masse_simulink + masse_bobine_et_plaque; % Actionneur
masse_aimant = 1/1000; % Aimant au bout

%c_amortissement = 0.35; % Ton amortissement concentré en N*s/m
alpha = 0.75;          % Coefficient de Rayleigh pour l'amortissement externe (résistance à l'air)
beta = 0;              % Coefficient de Rayleigh pour l'amortissement interne (forces dans le matériel)

%% 1. Création des matrices élémentaires de la poutre
% Basé sur les équations (9) et (10) du document
k_b = (E*J / le^3) * [12, 6*le, -12, 6*le;
                      6*le, 4*le^2, -6*le, 2*le^2;
                     -12, -6*le, 12, -6*le;
                      6*le, 2*le^2, -6*le, 4*le^2];
m_b = (mu * le / 420) * [156, 22*le, 54, -13*le;
                         22*le, 4*le^2, 13*le, -3*le^2;
                         54, 13*le, 156, -22*le;
                        -13*le, -3*le^2, -22*le, 4*le^2];

%% 2. Assemblage des matrices globales
M_g = zeros(ndof, ndof);
K_g = zeros(ndof, ndof);
for i = 1:ne
    idx = (2*i-1):(2*i+2); % Les 4 DDL concernés par l'élément i
    M_g(idx, idx) = M_g(idx, idx) + m_b;
    K_g(idx, idx) = K_g(idx, idx) + k_b;
end

%% 3. Ajout des masses ponctuelles et de l'amortissement
% Identification des noeuds les plus proches
noeud_act = round(pos_actionneur_et_masse / le) + 1;
ddl_act = 2 * noeud_act - 1; % DDL de déplacement (impair)

noeud_bout = nnodes;
ddl_bout = 2 * noeud_bout - 1;

% Ajout des masses ponctuelles à la diagonale de la matrice de masse globale
M_g(ddl_act, ddl_act) = M_g(ddl_act, ddl_act) + masse;
M_g(ddl_bout, ddl_bout) = M_g(ddl_bout, ddl_bout) + masse_aimant;

% Matrice d'amortissement global
C_g = alpha * M_g + beta * K_g;

%% 4. Application des conditions aux limites (Encastrement)
ddl_libres = 3:ndof;
M_f = M_g(ddl_libres, ddl_libres);
K_f = K_g(ddl_libres, ddl_libres);
C_f = C_g(ddl_libres, ddl_libres);

%% 5. Transformation modale (on conserve les 3 premiers modes)
[Phi, Omega2] = eig(K_f, M_f);
[omega_tries, index] = sort(diag(Omega2));
Phi = Phi(:, index);
% Couper à 3 modes
n_modes = 3;
Phi_tronque = Phi(:, 1:n_modes);

% Matrices généralisées (Equations 41 et 47)
M_bar = Phi_tronque' * M_f * Phi_tronque;
K_bar = Phi_tronque' * K_f * Phi_tronque;
C_bar = Phi_tronque' * C_f * Phi_tronque;

%% 6. Construction du modèle d'état (State-Space)
A_ss = [zeros(n_modes, n_modes), eye(n_modes);
    -inv(M_bar)*K_bar,       -inv(M_bar)*C_bar];
    
F_ext = zeros(length(ddl_libres), 1);
idx_force_reduit = ddl_act - 2; 
F_ext(idx_force_reduit) = 1; 

B_ss = [zeros(n_modes, 1);
     inv(M_bar) * (Phi_tronque' * F_ext)]; 
     
C_ss = zeros(2, 2*n_modes);
idx_bout_reduit = ddl_bout - 2;
C_ss(1, 1:n_modes) = Phi_tronque(idx_bout_reduit, :); % Position du bout
C_ss(2, 1:n_modes) = Phi_tronque(idx_force_reduit, :); % Position de l'actionneur
D_ss = zeros(2, 1);

%% 7. Création de l'objet d'état sous MATLAB
sys = ss(A_ss, B_ss, C_ss, D_ss);
disp('Matrice A_ss:'); disp(A_ss);
disp('Matrice B_ss:'); disp(B_ss);
disp('Matrice C_ss:'); disp(C_ss);

%% 8. Calcul de la position de repos (Statique sous gravité)
g = 9.81; % Accélération gravitationnelle m/s^2

% Création du vecteur de force de gravité pour tous les DDL
F_gravite_g = zeros(ndof, 1);
poids_lineique = -mu * g; % Force répartie due au poids propre (vers le bas)

% Force équivalente pour chaque élément (répartition nodale)
F_elem_grav = poids_lineique * le / 2 * [1; le/6; 1; -le/6]; 
for i = 1:ne
    idx = (2*i-1):(2*i+2);
    F_gravite_g(idx) = F_gravite_g(idx) + F_elem_grav;
end

% Ajout du poids concentré des masses (Actionneur + masse simulink + aimant)
F_gravite_g(ddl_act) = F_gravite_g(ddl_act) - masse * g;
F_gravite_g(ddl_bout) = F_gravite_g(ddl_bout) - masse_aimant * g;

% Retrait des DDL encastrés (conditions aux limites)
F_gravite_f = F_gravite_g(ddl_libres);

% Résolution statique : K * x = F -> x = K \ F
deplacement_statique = K_f \ F_gravite_f;

% Extraction des positions de repos
repos_actionneur = deplacement_statique(idx_force_reduit);
repos_bout = deplacement_statique(idx_bout_reduit);
disp(repos_actionneur)
disp(repos_bout)

fprintf('\n--- Positions de repos statique (sous l''effet de la gravité) ---\n');
fprintf('Déflexion à l''actionneur : %g m (%g mm)\n', repos_actionneur, repos_actionneur * 1000);
fprintf('Déflexion au bout de la lame : %g m (%g mm)\n\n', repos_bout, repos_bout * 1000);

%% 9. Simulation et extraction des données temporelles
dt = 10e-5;             % pas temporel
temps_simulation = 5;  % Durée de la simulation en secondes
t = 0:dt:temps_simulation; % Création du vecteur de temps
amplitude_dirac = 0.1;

%Force externe
F_ext = zeros(length(t), 1);
F_ext(1) = amplitude_dirac / dt; % Impulsion au temps t=0

[y_lsim, t_out] = lsim(sys, F_ext, t);

% Si on veut que la simulation oscille autour de la position de repos, on l'ajoute :
pos_bout_m2 = y_lsim(:, 1) + repos_bout;
pos_actionneur_m2 = y_lsim(:, 2) + repos_actionneur;

%% 10. Affichage des résultats
if plot_position
    figure;
    plot(t_out, pos_bout_m2, 'b', t_out, pos_actionneur_m2, 'r');
    grid on;
    title('Position selon le temps (Impulsion + Gravité)');
    xlabel('Temps [s]');
    ylabel('Déplacement [m]');
    legend('Bout de la lame', 'Actionneur');
end

%% --- Analyse fréquentielle (FFT) pour extraire les modes ---
if faire_fft
    %% --- 1. Analyse pour le bout de la lame (h) ---
    % 1. Paramètres du signal (on centre le signal sur 0 pour une meilleure FFT)
    h = pos_bout_m2 - mean(pos_bout_m2); 
    Fs = 1/dt;               % Fréquence d'échantillonnage (Hz)
    L_sig = length(h);       % Longueur du signal analysé
    
    Y = fft(h);
    
    P2 = abs(Y/L_sig);
    P1 = P2(1:floor(L_sig/2)+1);
    P1(2:end-1) = 2*P1(2:end-1); 
    
    f = Fs*(0:floor(L_sig/2))/L_sig;
    
    figure('Name', 'Analyse Spectrale (FFT) - Bout de la lame', 'Color', 'w');
    plot(f, P1, 'b-', 'LineWidth', 1.5, 'DisplayName', 'FFT du bout de la lame');
    hold on; grid on;
    
    xlim([1, 200]); 
    title('FFT du bout de la lame (0 - 200 Hz)');
    xlabel('Fréquence (Hz)');
    ylabel('|P1(f)| (Amplitude)');
    legend('Location', 'northeast');
    
    %% --- 2. Analyse pour la position de l'actionneur (h_act) ---
    h_act = pos_actionneur_m2 - mean(pos_actionneur_m2);
    L_sig_act = length(h_act); 
    
    Y_act = fft(h_act);
    
    P2_act = abs(Y_act/L_sig_act);
    P1_act = P2_act(1:floor(L_sig_act/2)+1);
    P1_act(2:end-1) = 2*P1_act(2:end-1); 
    
    f_act = Fs*(0:floor(L_sig_act/2))/L_sig_act;
    
    figure('Name', 'Analyse Spectrale (FFT) - Actionneur', 'Color', 'w');
    plot(f_act, P1_act, 'b-', 'LineWidth', 1.5, 'DisplayName', 'FFT de l''actionneur');
    hold on; grid on;
    
    xlim([1, 200]); 
    title("FFT de la position de l'actionneur (0 - 200 Hz)");
    xlabel('Fréquence (Hz)');
    ylabel('|P1(f)| (Amplitude)');
    legend('Location', 'northeast');
end
disp(toc)