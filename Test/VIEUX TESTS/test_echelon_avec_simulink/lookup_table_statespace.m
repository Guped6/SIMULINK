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
n_modes = 3;     % CORRECTION: Déclaré  ici pour l'initialisation des tables
faire_fft = true;
plot_position = false;

%% Paramètres des masses et forces
pos_actionneur_et_masse = 0.146; % Position en mètre
masse_bobine_et_plaque = 40/1000;
masse_aimant = 1/1000; % Aimant au bout

alpha = 0.7;          % Coefficient de Rayleigh pour l'amortissement externe (résistance à l'air)
beta = 0.0001;        % Coefficient de Rayleigh pour l'amortissement interne (forces dans le matériel)

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
idx_a_tester = 1; 
masse_test_simulink = vecteur_masse(idx_a_tester);
masse_totale_test = masse_test_simulink + masse_bobine_et_plaque;
fprintf('Test avec masse_simulink = %g g (Masse totale noeud act = %g g)\n', masse_test_simulink*1000, masse_totale_test*1000);

%% 8. Calcul de la position de repos de BASE (Statique sous gravité)
g = 9.81; % Accélération gravitationnelle m/s^2

% --- NOUVEAUX PARAMÈTRES INDÉPENDANTS POUR LE REPOS ---
% Définis ici les masses (en kg) utilisées UNIQUEMENT pour calculer l'offset de repos.
masse_pesee_pos_repos = 100/1000;
masse_repos_actionneur = 40/1000+masse_pesee_pos_repos; % Ex: 40g (indépendant de masse_bobine_et_plaque)
masse_repos_bout = 1/1000;        % Ex: 1g (indépendant de masse_aimant)
% ------------------------------------------------------

F_gravite_g = zeros(ndof, 1);
poids_lineique = -mu * g;
F_elem_grav = poids_lineique * le / 2 * [1; le/6; 1; -le/6]; 

% Gravité répartie de la poutre elle-même
for i = 1:ne
    idx = (2*i-1):(2*i+2);
    F_gravite_g(idx) = F_gravite_g(idx) + F_elem_grav;
end

% Ajout des masses ponctuelles indépendantes pour la déflexion statique
F_gravite_g(ddl_act) = F_gravite_g(ddl_act) - masse_repos_actionneur * g;
F_gravite_g(ddl_bout) = F_gravite_g(ddl_bout) - masse_repos_bout * g;

F_gravite_f = F_gravite_g(ddl_libres);
K_f_base = K_g_base(ddl_libres, ddl_libres); % K ne dépend pas de la masse

% Calcul du déplacement
deplacement_statique = K_f_base \ F_gravite_f;
repos_actionneur = deplacement_statique(idx_force_reduit);
repos_bout = deplacement_statique(idx_bout_reduit);

fprintf('\n--- Positions de repos statique (Paramètres indépendants) ---\n');
fprintf('Masse statique actionneur : %g g | Masse statique bout : %g g\n', masse_repos_actionneur*1000, masse_repos_bout*1000);
fprintf('Déflexion à l''actionneur : %g mm\n', repos_actionneur * 1000);
fprintf('Déflexion au bout de la lame : %g mm\n\n', repos_bout * 1000);
%% 9. Simulation et extraction des données temporelles
dt = 10e-5;             
temps_simulation = 5;  
t = 0:dt:temps_simulation; 
amplitude_dirac = 0.0105;
sys_test = ss(A_table(:,:,idx_a_tester), B_table(:,:,idx_a_tester), C_table(:,:,idx_a_tester), D_table(:,:,idx_a_tester));

% MODIFICATION : Force externe (Impulsion + Gravité de la masse ajoutée en continu)
F_ext_sim = zeros(length(t), 1);

% 1. Poids constant de la masse ajoutée (entrée continue négative)
F_ext_sim = F_ext_sim - (masse_test_simulink * g); 

% 2. Impulsion rectangulaire de 10 millisecondes
duree_impulsion = 10e-3; % 10 millisecondes (0.01 s)
nb_indices_impulsion = round(duree_impulsion / dt); % Calcul du nombre d'échantillons (devrait être 100)
amplitude_rect = amplitude_dirac / duree_impulsion; % Hauteur de la force pour conserver l'aire de l'impulsion

% Application de l'impulsion sur les 10 premières millisecondes
F_ext_sim(1:nb_indices_impulsion) = F_ext_sim(1:nb_indices_impulsion) + amplitude_rect; 

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

%% --- Analyse fréquentielle (FFT) via Simulink ---
if faire_fft
    fprintf('Calcul de la FFT sur les données Simulink...\n');
    
    % Extraction des données de l'objet 'out' généré par la fonction sim()
    out = sim('test_lookup_table')

    t_sim = out.tout;
    pos_bout_sim = out.sim_pos_bout; % Doit correspondre au nom dans le bloc To Workspace
    
    % --- OPTIONNEL MAIS RECOMMANDÉ ---
    % Si ton bloc Step ajoute la masse à un temps précis (ex: 0.5s), 
    % il vaut mieux isoler le signal à partir de ce moment.
    temps_ajout_masse = 20; % Modifie ceci pour correspondre au "Step time" de Simulink
    idx_valides = find(t_sim >= temps_ajout_masse);
    
    h = pos_bout_sim(idx_valides);
    t_fft = t_sim(idx_valides);
    
    % Retrait de la composante continue (DC offset) pour mieux voir les pics
    h = h - mean(h); 
    
    % Calcul du dt moyen (au cas où, bien qu'on ait forcé un pas fixe)
    dt_sim = mean(diff(t_fft));
    Fs = 1/dt_sim;               
    L_sig = length(h);       
    
    % Calcul de la transformée
    Y = fft(h);
    
    % Calcul des amplitudes bilatérales puis unilatérales
    P2 = abs(Y/L_sig);
    P1 = P2(1:floor(L_sig/2)+1);
    P1(2:end-1) = 2*P1(2:end-1); 
    
    % Vecteur des fréquences
    f = Fs*(0:floor(L_sig/2))/L_sig;
    
    % Affichage
    figure('Name', 'Analyse Spectrale (FFT) - Bout de la lame (Simulink)', 'Color', 'w');
    semilogy(f, P1, 'b-', 'LineWidth', 1.5, 'DisplayName', 'FFT (Simulink)');
    hold on; grid on;
    xlim([1, 200]); % Tu peux ajuster la plage de fréquence ici
    title('FFT de la réponse au BOUT de la lame suite à l''ajout de la masse');
    xlabel('Fréquence (Hz)');
    ylabel('|Amplitude|');
    legend('Location', 'northeast');
    fprintf('Calcul de la FFT sur les données Simulink...\n');


    % Extraction des données de l'objet 'out' généré par la fonction sim()
    t_sim = out.tout;
    pos_bout_sim = out.sim_pos_actionneur; % Doit correspondre au nom dans le bloc To Workspace
    
    % --- OPTIONNEL MAIS RECOMMANDÉ ---
    % Si ton bloc Step ajoute la masse à un temps précis (ex: 0.5s), 
    % il vaut mieux isoler le signal à partir de ce moment.
    temps_ajout_masse = 20; % Modifie ceci pour correspondre au "Step time" de Simulink
    idx_valides = find(t_sim >= temps_ajout_masse);
    
    h = pos_bout_sim(idx_valides);
    t_fft = t_sim(idx_valides);
    
    % Retrait de la composante continue (DC offset) pour mieux voir les pics
    h = h - mean(h); 
    
    % Calcul du dt moyen (au cas où, bien qu'on ait forcé un pas fixe)
    dt_sim = mean(diff(t_fft));
    Fs = 1/dt_sim;               
    L_sig = length(h);       
    
    % Calcul de la transformée
    Y = fft(h);
    
    % Calcul des amplitudes bilatérales puis unilatérales
    P2 = abs(Y/L_sig);
    P1 = P2(1:floor(L_sig/2)+1);
    P1(2:end-1) = 2*P1(2:end-1); 
    
    % Vecteur des fréquences
    f = Fs*(0:floor(L_sig/2))/L_sig;
    
    % Affichage
    figure('Name', 'Analyse Spectrale (FFT) - Bout de la lame (Simulink)', 'Color', 'w');
    semilogy(f, P1, 'b-', 'LineWidth', 1.5, 'DisplayName', 'FFT (Simulink)');
    hold on; grid on;
    xlim([1, 200]); % Tu peux ajuster la plage de fréquence ici
    title('FFT de la réponse de l ACTIONNEUR suite à l''ajout de la masse');
    xlabel('Fréquence (Hz)');
    ylabel('|Amplitude|');
    legend('Location', 'northeast');


end
disp(toc)