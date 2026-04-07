%% 
close all
clear all
clc
tic
% J'ai ajouté affichage_rapide, on voit moins bien en la poutre durant la simulation mais c'est bcp
% plus vite et les résultats finaux sont identiques.
% c est l'amortissement (+ haut = plus amorti), pas d'unité. Provient
% principalement des forces externes (air...)

%% Paramètres des forces/masses
faire_echelon = true; % Vrai pour appliquer une force constante soudaine (échelon)
masse_echelon_g = 50; % En grammes. Masse de l'échelon ajoutée vers le bas.
T_echelon = 0; % Temps exact où la masse est déposée, mesuré en SECONDES
F_constante = 0; % Force appliqueée en tout temps à la position de l'actionneur (s'aditionne à l'échelon), positif = vers le haut
pos_actionneur_et_masse = 0.1345; % en mètre, position où on applique la force constante et l'échelon
masse = 61/1000; %en kg, masse de la bobine de l'actionneur
masse_aimant = 1/1000; % masse en Kg de l'aimant au bout de la lame
c = 0.35443; % Pour l'amortissement, sans unité, externe à la poutre 
g = 9.81;  % m/s^2

% Calcul automatique de la force de l'échelon (négatif car vers le bas)
Force_echelon = -(masse_echelon_g / 1000) * g; 

%% Paramètres de La poutre
b = 7.08e-2;        % Base
h = 1.5875e-3;      % Hauteur
L = 24.3e-2;        % Longueur
nx = 20;            % Nb d'éléments spatiaux (attention à la stabilité)

%% Paramètres de simulation
debut_pos_repos = true;
calcul_pos_repos_avec_masses = false; % La lame est initialement au repos AVEC ses masses
affichage_rapide = true;% affiche la poutre chaque 500 pas temporels, accélère énormément la simulation
pas_d_affichage = false;
dt = 3e-5; % Pas de simulation en secondes (le rendre plus grand va rendre la simulation instable)
temps_simulation = 20; % temps en secondes

%% sorties 
plot_pos_bout= true;
plot_pos_actionneur = true;
faire_fft = true;
produire_fct_transfert = false; % SEULEMENT UTILISER AVEC debut_pos_repos = true!!!

% tf du bout
npb = 6; %nombre de poles
nzb = 2; %nombre de zéros

% tf de l'actionneur
npa = 4; %nombre de poles
nza = 1; %nombre de zéros
facteur_identification_s = 50; % La fréquence baisse de ce facteur pour l'identification, sa accelere le code

%% Paramètres du Matériau
E = 18.6e9;      % Module de Young  24 GPa (pour le Fr4 selon wikipedia)
dens = 1850;     % Densité Kg/m^3
mu =  dens*b*h;  % Masse linéique kg/m
J = b*h^3/12;    % Moment d'aire

%% Code
dx =   L/(nx-1);  % incrément spatial
dx_n = dx/L;      % On travaille en dx normalisé
idx_force = round(pos_actionneur_et_masse / dx) + 2;
idx_bout = round(L / dx) + 2;

% Création d'un vecteur de masse linéique effective
mu_eff = mu * ones(1, nx);
mu_eff_intrinseque = mu_eff;
mu_eff(idx_force) = mu_eff(idx_force) + (masse / dx);
mu_eff(nx) = mu_eff(nx) + (masse_aimant / dx);

% Les paramètres de raideur deviennent des vecteurs (1 x nx)
kappa_eff = sqrt(E*J ./ (mu_eff * L^4));
mu_simu_eff = kappa_eff * dt / dx_n^2;

% Nouveaux coefficients vecteurs
coeff1 = (2 - 6 * mu_simu_eff.^2);
coeff2 = (4 * mu_simu_eff.^2);
coeff3 = -mu_simu_eff.^2;

% Vecteurs d'amortissement et de force
alpha = (c * dt) ./ (mu_eff * 2);
Facteur_a1 = 1 ./ (alpha + 1);
Facteur_a2 = (alpha - 1) ./ (alpha + 1);

coeff1_a = coeff1 .* Facteur_a1; 
coeff2_a = coeff2 .* Facteur_a1;
coeff3_a = coeff3 .* Facteur_a1;

effet_gravite = -g * dt^2 ; 
effet_gravite_a = effet_gravite .* Facteur_a1;
facteur_force_eff = (dt^2 ./ (mu_eff *dx)) .* Facteur_a1;

nt = round(temps_simulation/dt);       % Nombre de pas temporels simulés

% CRÉATION DE L'ÉCHELON DE FORCE
F = F_constante * ones(1, nt+50);   % Tableau de F de base
idx_echelon = round(T_echelon / dt); % Convertit les secondes en indice de tableau
if idx_echelon < 1
    idx_echelon = 1;
end
if faire_echelon
    % À partir du temps T_echelon jusqu'à la fin de la simulation, on applique la force
    F(idx_echelon:end) = Force_echelon + F_constante; 
end

x  = -dx:dx:L+dx; % grille spatiale
nx = nx+2;

% Stiffness params
kappa = sqrt(E*J/(mu*L^4));

% Doit être inférieur à 1/2 pour que ca soit stable
mu_simu = kappa*dt/dx_n^2;
if(mu_simu >1/2)
       warning('La simulation ne sera pas stable !')
end

f1 = 1.875^2*kappa/(2*pi);

%% Conditions initiales
if debut_pos_repos
    % matrice de rigidité K et du vecteur force B
    K = zeros(nx, nx);
    B = zeros(nx, 1);
    
    % 2. Remplissage pour les nœuds internes (i = 3 à nx-2)
    for i = 3:nx-2
        K(i, i-2) = -coeff3_a(i);
        K(i, i-1) = -coeff2_a(i);
        K(i, i)   = 1 - coeff1_a(i) - Facteur_a2(i);
        K(i, i+1) = -coeff2_a(i);
        K(i, i+2) = -coeff3_a(i);
        
        % Gravité
        if calcul_pos_repos_avec_masses
            B(i) = effet_gravite_a(i);
        else
            ratio_masse = mu_eff_intrinseque(i) / mu_eff(i);
            B(i) = effet_gravite_a(i) * ratio_masse;
        end
    end
    
    % 3. Ajout de la force constante
    B(idx_force) = B(idx_force) + (F_constante * facteur_force_eff(idx_force));
    
    % 4. Conditions aux limites
    K(1, 1) = 1; B(1) = 0;
    K(2, 2) = 1; B(2) = 0;
    K(nx-1, nx-3) = 1; K(nx-1, nx-2) = -2; K(nx-1, nx-1) = 1; B(nx-1) = 0;
    K(nx, nx-2)   = 1; K(nx, nx-1)   = -2; K(nx, nx)   = 1; B(nx)   = 0;
    
    % 5. Résolution du système statique
    w = (K \ B)'; 
    w_repos = w;
    
    % DÉFINITION DE LA POSITION DU CAPTEUR
    % Le capteur est placé 7.5 mm (0.0075 m) sous la lame à son état de repos
    z_capteur = w_repos(idx_force) - 0.0075;
else
    % Fallback si pas de position de repos calculée
    z_capteur = -0.0075; 
end

%% Calcul de la solution statique
w_old = w;                                  % un pas dans le passé
w_new = zeros(1,nx);                        % ce qui sera calculé à chaque tour
w_init = w;                                 % Préservation de la condition initiale

%% Vecteurs de position
pos_bout = zeros(1,nt+1);
pos_actionneur = zeros(1,nt+1);

%% Précalcul des params de simulation pour accélerer la boucle
coeff1 = (2-6*mu_simu^2);
coeff2 = (4*mu_simu^2);
coeff3 = -mu_simu^2;
facteur_force = dt^2 / (mu*dx); 

%% Indice de l'élément de longueur auquel appliquer la force
[a,idx_force] = min(abs(x-pos_actionneur_et_masse));

%% Nouveaux coefficients pour amortissement
alpha = (c*dt)/(mu*2);

%% Préparation de la figure
if pas_d_affichage == false
h=plot(x,1000*w_init,x,1000*w_new, ...
    x(idx_force), 0, 'g.', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
xlabel('x [m]')
ylabel('Déflexion [mm]')
ylim([-10,3])
grid on
end

%% Préparation avant la boucle
i_interne = 3:nx-2; 
w_new = w; 

%% Boucle de simulation
for n = 0:nt 
    w_new(i_interne) = coeff1_a(i_interne).*w(i_interne) + ...
                       coeff2_a(i_interne).*(w(i_interne+1)+w(i_interne-1)) + ...
                       coeff3_a(i_interne).*(w(i_interne+2)+w(i_interne-2)) + ...
                       w_old(i_interne).*Facteur_a2(i_interne) + effet_gravite_a(i_interne);
    
    % Force
    idx_t = n + 1; 
    w_new(idx_force) = w_new(idx_force) + (F(idx_t) * facteur_force_eff(idx_force));
    
    % Conditions limites 
    w_new(1:2) = 0;                 
    w_new(end-1) = 2*w_new(end-2) - w_new(end-3);    
    w_new(end) = 2*w_new(end-1) - w_new(end-2);
    
    % Mise à jour
    w_old = w;
    w = w_new;
    
    pos_bout(idx_t) = w(end);
    pos_actionneur(idx_t) = w(idx_force); 
    
    % Affichage 
    if pas_d_affichage == false
        if affichage_rapide == true && mod(n,500) == 0
            set(h(2),'Ydata',1000*w_new);
            drawnow
        elseif affichage_rapide == false
            set(h(2),'Ydata',1000*w_new);
            drawnow
        end
    end
end

% Conversion de la position absolue de l'actionneur en distance mesurée par le capteur
distance_capteur = pos_actionneur - z_capteur;

%% Figures de la position selon le temps
if plot_pos_bout
figure
plot((0:dt:(nt*dt)),pos_bout * 1000) % Conversion en mm
grid
title('Position du bout de la lame selon le temps')
ylabel('Position (mm)')
xlabel('Temps (s)')
% Centre l'oscillation sur zéro pour la FFT
pos_repos = mean(pos_bout);
h_fft = pos_bout(idx_echelon:end) - pos_repos; % Utilise le bon index d'échelon
h_fft = h_fft(:); 
end

if plot_pos_actionneur
figure
% On trace maintenant la distance lue par le capteur (en mm)
plot((0:dt:(nt*dt)), distance_capteur * 1000) 
grid
title("Distance mesurée par le capteur de position (7.5 mm au repos)")
ylabel('Distance au capteur (mm)')
xlabel('Temps (s)')
end

%% --- Analyse fréquentielle (FFT) pour extraire les modes ---
if faire_fft
Fs = 1/dt;               
L_sig = length(h_fft);       
Y = fft(h_fft);
P2 = abs(Y/L_sig);
P1 = P2(1:floor(L_sig/2)+1);
P1(2:end-1) = 2*P1(2:end-1); 
f = Fs*(0:floor(L_sig/2))/L_sig;

% --- MODIFICATION EN DÉCIBELS (dB) ---
P1_dB = 20 * log10(P1 + eps); % Conversion de l'amplitude en dB avec protection

figure('Name', 'Analyse Spectrale (FFT)', 'Color', 'w');
plot(f, P1_dB, 'b-', 'LineWidth', 1.5, 'DisplayName', 'FFT du bout de la lame');
grid on;
hold on;
xlim([1, 100]); 
title('Spectre du déplacement de l''extrémité (0 - 100 Hz)');
xlabel('Fréquence (Hz)');
ylabel('Amplitude (dB)'); % Label modifié pour refléter l'unité
end

%% Calcul de la fct de transfert
if produire_fct_transfert 
    disp('calcul fct_transfert')
    pos_repos = w_init(idx_bout); 
    h_tf = pos_bout(1:nt) - pos_repos; 
    h_tf = h_tf(:); 
    
    opt = tfestOptions('SearchMethod', 'lm'); 
    
    u = F(1:nt); 
    u = u(:); 
    u_d = decimate(u,facteur_identification_s);
    
    data = iddata(decimate(h_tf,facteur_identification_s), u_d, facteur_identification_s*dt); 
    
    sys_identifie = tfest(data, npb, nzb, opt);
    tf_bout_poutre = tf(sys_identifie);
        
    disp('Fonction de transfert du bout :');
    [num_bout, den_bout] = tfdata(tf_bout_poutre, 'v');
    disp(num_bout);
    disp(den_bout);
    
    figure('Name', 'Comparaison Données bout vs Modèle tfest');
    compare(data, sys_identifie); 
    grid on;
    title(['Comparaison Temporelle bout - Ordre ', num2str(npb)]);
    
    %-------------------------------------------------------------------------
    pos_repos = w_init(idx_force); 
    h_tf2 = pos_actionneur(1:nt) - pos_repos; 
    h_tf2 = h_tf2(:); 
    
    data = iddata(decimate(h_tf2,facteur_identification_s), u_d, facteur_identification_s*dt);
    
    sys_identifie = tfest(data, npa, nza,opt);
    tf_actionneur = tf(sys_identifie);
        
    disp("Fonction de transfert de l'actionneur :");
    [num_actionneur, den_actionneur] = tfdata(tf_actionneur, 'v');
    disp(num_actionneur);
    disp(den_actionneur);
    
    figure('Name', 'Comparaison Données actionneur vs Modèle tfest');
    compare(data, sys_identifie); 
    grid on;
    title(['Comparaison Temporelle actionneur - Ordre ', num2str(npa)]);
end
disp(toc)