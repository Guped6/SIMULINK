close all;
tic();

%% Temporaire
sat_proc_max = 1;
sat_proc_min = -1;

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
n_modes = 3;     % CORRECTION: Déclaré ici pour l'initialisation des tables
faire_fft = false;
plot_position = false;

%% Paramètres des masses et forces
pos_actionneur_et_masse = 0.146; % Position en mètre
masse_bobine_et_plaque = 40/1000;
masse_aimant = 1/1000; % Aimant au bout

alpha = 10;          % Coefficient de Rayleigh pour l'amortissement externe (résistance à l'air)
beta = 0.00;        % Coefficient de Rayleigh pour l'amortissement interne (forces dans le matériel)

%% 0. Initialiser les matrices 3D pour les tables
% Plage de masse de 0 à 100g par bonds de 1g
vecteur_masse = 0 : 0.001 : 0.100; 
N_points = length(vecteur_masse);

% A_ss est de taille (6x6), donc A_table sera (6x6xN_points)
A_table = zeros(2*n_modes, 2*n_modes, N_points);
B_table = zeros(2*n_modes, 1, N_points);
C_table = zeros(2, 2*n_modes, N_points);
D_table = zeros(2, 1, N_points);

%% 1. Création des matrices élémentaires de la poutre
k_b = (E*J / le^3) * [12, 6*le, -12, 6*le;
                      6*le, 4*le^2, -6*le, 2*le^2;
                     -12, -6*le, 12, -6*le;
                      6*le, 2*le^2, -6*le, 4*le^2];
m_b = (mu * le / 420) * [156, 22*le, 54, -13*le;
                         22*le, 4*le^2, 13*le, -3*le^2;
                         54, 13*le, 156, -22*le;
                        -13*le, -3*le^2, -22*le, 4*le^2];

%% 2. Assemblage des matrices globales de BASE (sans masses ponctuelles)
M_g_base = zeros(ndof, ndof);
K_g_base = zeros(ndof, ndof);
for i = 1:ne
    idx = (2*i-1):(2*i+2); % Les 4 DDL concernés par l'élément i
    M_g_base(idx, idx) = M_g_base(idx, idx) + m_b;
    K_g_base(idx, idx) = K_g_base(idx, idx) + k_b;
end

% Identification des noeuds les plus proches (calculé une seule fois)
noeud_act = round(pos_actionneur_et_masse / le) + 1;
ddl_act = 2 * noeud_act - 1; 
noeud_bout = nnodes;
ddl_bout = 2 * noeud_bout - 1;
ddl_libres = 3:ndof;
idx_force_reduit = ddl_act - 2; 
idx_bout_reduit = ddl_bout - 2;

%% 3. Boucle de création de la Lookup Table LPV
fprintf('Génération de la lookup table...\n');
for i = 1:N_points
    % INERTIE : On inclut la masse TOTALE (plaque + masse ajoutée) pour la dynamique
    masse_actuelle = vecteur_masse(i) + masse_bobine_et_plaque;
    
    M_g = M_g_base;
    K_g = K_g_base;
    
    % Ajout des masses ponctuelles (Inertie)
    M_g(ddl_act, ddl_act) = M_g(ddl_act, ddl_act) + masse_actuelle;
    M_g(ddl_bout, ddl_bout) = M_g(ddl_bout, ddl_bout) + masse_aimant;
    
    % Matrice d'amortissement global
    C_g = alpha * M_g + beta * K_g;
    
    % Application des conditions aux limites (Encastrement)
    M_f = M_g(ddl_libres, ddl_libres);
    K_f = K_g(ddl_libres, ddl_libres);
    C_f = C_g(ddl_libres, ddl_libres);
    
    % Transformation modale
    [Phi, Omega2] = eig(K_f, M_f);
    [omega_tries, index] = sort(diag(Omega2));
    Phi = Phi(:, index);
    
    % Troncature
    Phi_tronque = Phi(:, 1:n_modes);
    
    % Matrices généralisées
    M_bar = Phi_tronque' * M_f * Phi_tronque;
    K_bar = Phi_tronque' * K_f * Phi_tronque;
    C_bar = Phi_tronque' * C_f * Phi_tronque;
    
    % Construction du modèle d'état
    A_ss = [zeros(n_modes, n_modes), eye(n_modes);
           -inv(M_bar)*K_bar,       -inv(M_bar)*C_bar];
        
    F_ext = zeros(length(ddl_libres), 1);
    F_ext(idx_force_reduit) = 1; 
    
    B_ss = [zeros(n_modes, 1);
            inv(M_bar) * (Phi_tronque' * F_ext)]; 
         
    C_ss = zeros(2, 2*n_modes);
    C_ss(1, 1:n_modes) = Phi_tronque(idx_bout_reduit, :); % Sortie 1 : Bout
    C_ss(2, 1:n_modes) = Phi_tronque(idx_force_reduit, :); % Sortie 2 : Actionneur
    D_ss = zeros(2, 1);
    
    % Assigner aux matrices 3D
    A_table(:,:,i) = A_ss;
    B_table(:,:,i) = B_ss;
    C_table(:,:,i) = C_ss;
    D_table(:,:,i) = D_ss;
end

sys_array = ss(A_table, B_table, C_table, D_table);
sys_array.SamplingGrid = struct('m_var', vecteur_masse);
fprintf('Lookup table générée avec succès.\n\n');

%% --- TEST TEMPOREL ET STATIQUE POUR UNE MASSE SPÉCIFIQUE ---
% On choisit un index dans la table (ex: index 51 correspond à 50g)
idx_a_tester = 51; 
masse_test_simulink = vecteur_masse(idx_a_tester);
masse_totale_test = masse_test_simulink + masse_bobine_et_plaque;
fprintf('Test avec masse_simulink = %g g (Masse totale noeud act = %g g)\n', masse_test_simulink*1000, masse_totale_test*1000);

%% 8. Calcul de la position de repos de BASE (Statique sous gravité de la structure)
g = 9.81; % Accélération gravitationnelle m/s^2
F_gravite_g = zeros(ndof, 1);
poids_lineique = -mu * g;
F_elem_grav = poids_lineique * le / 2 * [1; le/6; 1; -le/6]; 
for i = 1:ne
    idx = (2*i-1):(2*i+2);
    F_gravite_g(idx) = F_gravite_g(idx) + F_elem_grav;
end

% MODIFICATION : On ne compte QUE la gravité de la plaque (40g) pour la position de repos statique de base
% La gravité de la masse ajoutée (masse_simulink) sera gérée dynamiquement en entrée du bloc LPV
F_gravite_g(ddl_act) = F_gravite_g(ddl_act) - masse_bobine_et_plaque * g;
F_gravite_g(ddl_bout) = F_gravite_g(ddl_bout) - masse_aimant * g;

F_gravite_f = F_gravite_g(ddl_libres);
K_f_base = K_g_base(ddl_libres, ddl_libres); % K ne dépend pas de la masse
deplacement_statique = K_f_base \ F_gravite_f;

repos_actionneur = deplacement_statique(idx_force_reduit);
repos_bout = deplacement_statique(idx_bout_reduit);

fprintf('\n--- Positions de repos statique (Sans masse ajoutée) ---\n');
fprintf('Déflexion à l''actionneur : %g mm\n', repos_actionneur * 1000);
fprintf('Déflexion au bout de la lame : %g mm\n\n', repos_bout * 1000);

%% 9. Simulation et extraction des données temporelles
dt = 10e-5;             
temps_simulation = 5;  
t = 0:dt:temps_simulation; 
amplitude_dirac = 0.1;

sys_test = ss(A_table(:,:,idx_a_tester), B_table(:,:,idx_a_tester), C_table(:,:,idx_a_tester), D_table(:,:,idx_a_tester));

% MODIFICATION : Force externe (Impulsion + Gravité de la masse ajoutée en continu)
F_ext_sim = zeros(length(t), 1);
% 1. Poids constant de la masse ajoutée (entrée continue négative)
F_ext_sim = F_ext_sim - (masse_test_simulink * g); 
% 2. Impulsion au temps t=0
F_ext_sim(1) = F_ext_sim(1) + (amplitude_dirac / dt); 

[y_lsim, t_out] = lsim(sys_test, F_ext_sim, t);

% La sortie y_lsim prend déjà en compte la déflexion de la masse_test_simulink grâce à F_ext_sim !
% On n'a plus qu'à y rajouter l'offset statique de base (poutre + plaque 40g)
pos_bout_m2 = y_lsim(:, 1) + repos_bout;
pos_actionneur_m2 = y_lsim(:, 2) + repos_actionneur; 

%% 10. Affichage des résultats
if plot_position
    figure;
    plot(t_out, pos_bout_m2, 'b', t_out, pos_actionneur_m2, 'r');
    grid on;
    title(['Position avec impulsion + gravité (Masse test: ', num2str(masse_test_simulink*1000), 'g)']);
    xlabel('Temps [s]');
    ylabel('Déplacement [m]');
    legend('Bout de la lame', 'Actionneur');
end

%% --- Analyse fréquentielle (FFT) ---
if faire_fft
    % 1. Analyse pour le bout de la lame (h)
    h = pos_bout_m2 - mean(pos_bout_m2); 
    Fs = 1/dt;               
    L_sig = length(h);       
    
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
end
disp(toc)