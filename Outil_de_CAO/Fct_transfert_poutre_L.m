%% 
close all
clear all
clc
tic
% J'ai ajouté affichage_rapide, on voit moins bien en la poutre durant la simulation mais c'est bcp
% plus vite et les résultats finaux sont identiques.

% c est l'amortissement (+ haut = plus amorti), pas d'unité. Provient
% principalement des forces externes (air...)


%% Paramêtre des forces/masses
faire_impulsion = true; % ignorer les 4 paramètres dessous si false
Force_impulsion = 0.1; % En newton, multiplie l'impulsion de dirac
T_impulsion = 1; % temps au début de l'impulsion mesuré en nb de pas temporels, pas en secondes 
Largeur_impulsion = 100;  % Durée de l'impulsion en pas temporels, théoriquement 0 (dirac) mais trop petit donne des résultats bizzards

F_constante = 0; % Force appliqueée en tout temps à la position de l'actionneur (s'aditionne à l'impulsion), positif = vers le haut
pos_actionneur_et_masse = 0.146; % en mètre, position où on applique la force constante et l'impusion

masse = 0.04; %en kg, masse de la bobine de l'actionneur (40g) + masse mesurée
masse_aimant = 1/1000; % masse en Kg de l'aimant au bout de la lame

c = 0.35; % Pour l'amortissement, sans unité, externe à la poutre 
g = 9.81;  % m/s^2
%% Paramètres de La poutre
b = 7.1e-2;        % Base 6 cm
h = 1.5e-3;     % Hauteur 1.56 mm
L = 24.3e-2;     % Longueur 24.6 cm 

nx = 20;         % Nb d'éléments spatiaux (attention à la stabilité)

%% Paramètres de simulation
debut_pos_repos = true;
calcul_pos_repos_avec_masses = false;
affichage_rapide = true;% affiche la poutre chaque 500 pas temporels, accélère énormément la simulation
pas_d_affichage = false;
dt = 3e-5; % Pas de simulation en secondes (le rendre plus grand va rendre la simulation instable)
temps_simulation = 5; % temps en secondes


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
E = 24e9;      % Module de Young  24 GPa (pour le Fr4 selon wikipedia)
dens = 1850;     % Densité Kg/m^3
mu =  dens*b*h;  % Masse linéique kg/m
J = b*h^3/12;    % Moment d'aire





%% Code
dx =   L/(nx-1);  % incrément spatial
dx_n = dx/L;     % On travaille en dx normalisé
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


% Impulsion
F = F_constante * ones(1, nt+50);   % Tableau de F pour le varier avec le temps
if faire_impulsion;
F(T_impulsion:T_impulsion+Largeur_impulsion) = Force_impulsion*(1/(Largeur_impulsion*dt))+F_constante; 
end


x  = -dx:dx:L+dx; % grille spatiale
nx = nx+2;



% Constantes physiques
g = 9.81; % m/s^2


% Stiffness params
kappa = sqrt(E*J/(mu*L^4));

% Doit être inférieur à 1/2 pour que ca soit stable
mu_simu = kappa*dt/dx_n^2;

if(mu_simu >1/2)
       warning('La simulation ne sera pas stable !')
end

f1 = sqrt( (1.875/L).^4*(E*J/mu))/(2*pi);  % Fréqeunce theorique de la fondamentale
f1 = 1.875^2*kappa/(2*pi);
%f1 = 4.73^2*kappa/(2*pi)  %% Clamped condition


%% Conditions initiales
if debut_pos_repos
    % matrice de rigidité K et du vecteur force B
    K = zeros(nx, nx);
    B = zeros(nx, 1);
    
    % 2. Remplissage pour les nœuds internes (i = 3 à nx-2)
    % équation dynamique devient en régime permanent : w_new = w_old = w
    for i = 3:nx-2
        K(i, i-2) = -coeff3_a(i);
        K(i, i-1) = -coeff2_a(i);
        K(i, i)   = 1 - coeff1_a(i) - Facteur_a2(i);
        K(i, i+1) = -coeff2_a(i);
        K(i, i+2) = -coeff3_a(i);
        
        % Gravité
        if calcul_pos_repos_avec_masses
            % Prend en compte mu_eff avec l'aimant et l'actionneur
            B(i) = effet_gravite_a(i);
        else
            % Position de repos de la poutre seule (sans les masses ajoutées).
            % Comme la matrice K contient déjà mu_eff, on ajuste la force 
            % avec le ratio des masses pour que le bilan statique reste exact.
            ratio_masse = mu_eff_intrinseque(i) / mu_eff(i);
            B(i) = effet_gravite_a(i) * ratio_masse;
        end
    end
    
    % 3. Ajout de la force constante éventuelle à la position de l'actionneur
    B(idx_force) = B(idx_force) + (F_constante * facteur_force_eff(idx_force));
    
    % 4. Conditions aux limites
    % Encastrement gauche
    K(1, 1) = 1; B(1) = 0;
    K(2, 2) = 1; B(2) = 0;
    
    % Bout libre droite
    K(nx-1, nx-3) = 1; K(nx-1, nx-2) = -2; K(nx-1, nx-1) = 1; B(nx-1) = 0;
    K(nx, nx-2)   = 1; K(nx, nx-1)   = -2; K(nx, nx)   = 1; B(nx)   = 0;
    
    % 5. Résolution du système linéaire statique [K]{W} = {B}
    w = (K \ B)'; % On transpose pour redevenir un vecteur ligne 1xnx
    w_repos = w;
end

%% Calcul de la solution statique


w_old = w;                                  % un pas dans le passé
w_new = zeros(1,nx);                        % ce qui sera calculé à chaque tour
w_init =w;                                  % Préservation de la condition initiale


%% Vecteur qui condiendra la position de l'extrémité de la lame en fonction
% du temps

pos_bout =zeros(1,nt+1);
pos_actionneur = zeros(1,nt+1);
%% Précalcul des params de simulation pour accélerer la boucle

 
coeff1 = (2-6*mu_simu^2);
coeff2 = (4*mu_simu^2);
coeff3 = -mu_simu^2;

facteur_force = dt^2 / (mu*dx); % Facteur à multiplier aux forces 


%% Indice de l'élément de longueur auquel appliquer la force
[a,idx_force] = min(abs(x-pos_actionneur_et_masse));
% x(idx_force) %Pour vérif

%% Nouveaux coefficients pour amoritssement
alpha = (c*dt)/(mu*2);

%% Préparation de la figure
if pas_d_affichage == false
h=plot(x,1000*w_init,x,1000*w_new, ...
    x(idx_force), 0, 'g.', 'MarkerSize', 10, 'MarkerFaceColor', 'r')
xlabel('x [m]')
ylabel('Déflexion [mm]')
ylim([-10,3])
grid on
end
t_force = 1;
%% Boucle de simulation
%% Préparation avant la boucle
i_interne = 3:nx-2; % On le calcule une seule fois !
w_new = w; % Initialiser w_new à la bonne taille

%% Boucle de simulation
for n = 0:nt 
    w_new(i_interne) = coeff1_a(i_interne).*w(i_interne) + ...
                       coeff2_a(i_interne).*(w(i_interne+1)+w(i_interne-1)) + ...
                       coeff3_a(i_interne).*(w(i_interne+2)+w(i_interne-2)) + ...
                       w_old(i_interne).*Facteur_a2(i_interne) + effet_gravite_a(i_interne);
    
    % Force
    idx_t = n + 1; % Remplace t_force
    w_new(idx_force) = w_new(idx_force) + (F(idx_t) * facteur_force_eff(idx_force));
    
    % Conditions limites 
    w_new(1:2) = 0;                 
    w_new(end-1) = 2*w_new(end-2) - w_new(end-3);    
    w_new(end) = 2*w_new(end-1) - w_new(end-2);
    
    % Mise à jour
    w_old = w;
    w = w_new;
    
    pos_bout(idx_t) = w(end);
    pos_actionneur(idx_t) = w(idx_force); % Maintenant très rapide grâce à la pré-allocation !
    
    % Affichage (inchangé)
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

   

%% Figures de la position selon le temps
if plot_pos_bout;
figure
plot((0:dt:(nt*dt)),pos_bout)
grid
title('Position du bout de la lame selon le temps')

% Centre l'oscillation sur zéro
pos_repos = mean(pos_bout);

h = pos_bout(T_impulsion:end) - pos_repos; % Soustraire pour ramener à 0
h = h(:); % Force h à être un vecteur colonne (N x 1)
end

if plot_pos_actionneur;
figure
plot((0:dt:(nt*dt)),pos_actionneur)
grid
title("Position de l'actionneur et de la plaque de pesée selon le temps")

% Centre l'oscillation sur zéro
pos_repos = mean(pos_actionneur);

h = pos_bout(T_impulsion:end) - pos_repos; % Soustraire pour ramener à 0
h = h(:); % Force h à être un vecteur colonne (N x 1)
end


%% --- Analyse fréquentielle (FFT) pour extraire les modes ---
if faire_fft;
% 1. Paramètres du signal
Fs = 1/dt;               % Fréquence d'échantillonnage (Hz)
L_sig = length(h);       % Longueur du signal analysé

% 2. Calcul de la Transformée de Fourier Rapide
Y = fft(h);

% 3. Calcul du spectre d'amplitude bilatéral, puis unilatéral
P2 = abs(Y/L_sig);
P1 = P2(1:floor(L_sig/2)+1);
P1(2:end-1) = 2*P1(2:end-1); 

% 4. Vecteur de fréquences correspondant
f = Fs*(0:floor(L_sig/2))/L_sig;

% 5. Création de la figure (Échelle Linéaire)
figure('Name', 'Analyse Spectrale (FFT)', 'Color', 'w');
plot(f, P1, 'b-', 'LineWidth', 1.5, 'DisplayName', 'FFT du bout de la lame');
grid on;
hold on;
% --- Limiter l'affichage à 200 Hz ---
xlim([1, 200]); 

title('Spectre du déplacement de l''extrémité (0 - 200 Hz)');
xlabel('Fréquence (Hz)');
ylabel('|P1(f)| (Amplitude)');
end

%% Calcul de la fct de transfert
if produire_fct_transfert 
    % 1. On centre à 0
    disp('calcul fct_transfert')
    pos_repos = w_init(idx_bout); % Utilise w_init calculé précédemment
    h = pos_bout(1:nt) - pos_repos; % On prend tout depuis le début
    h = h(:); % Vecteur colonne
    
    
    opt = tfestOptions('SearchMethod', 'lm'); %parametres de tfest
    % 2. On prend le vecteur de force réel utilisé dans la boucle
    % On s'assure qu'il a la même longueur que h (nt éléments)
    u = F(1:nt); 
    u = u(:); % Vecteur colonne
    u_d = decimate(u,facteur_identification_s);
    % 3. Création de l'objet data
    data = iddata(decimate(h,facteur_identification_s), u_d, facteur_identification_s*dt); 
    
    % 4. Identification
    sys_identifie = tfest(data, npb, nzb, opt);
    tf_bout_poutre = tf(sys_identifie);
        
    disp('Fonction de transfert du bout :');
    [num_bout, den_bout] = tfdata(tf_bout_poutre, 'v');
    disp(num_bout);
    disp(den_bout);
    % Vérification visuelle
    figure('Name', 'Comparaison Données bout vs Modèle tfest');
    compare(data, sys_identifie); 
    grid on;
    title(['Comparaison Temporelle bout - Ordre ', num2str(npb)]);
        %-------------------------------------------------------------------------
        % 1. On centre à 0
    pos_repos = w_init(idx_force); % Utilise w_init calculé précédemment
    h = pos_actionneur(1:nt) - pos_repos; % On prend tout depuis le début
    h = h(:); % Vecteur colonne
    
   
    
    % 3. Création de l'objet data
    data = iddata(decimate(h,facteur_identification_s), u_d, facteur_identification_s*dt);
    
    % 4. Identification
    sys_identifie = tfest(data, npa, nza,opt);
    tf_actionneur = tf(sys_identifie);
        
    disp("Fonction de transfert de l'actionneur :");
    [num_actionneur, den_actionneur] = tfdata(tf_actionneur, 'v');
    disp(num_actionneur);
    disp(den_actionneur);

    
    % Vérification visuelle
    figure('Name', 'Comparaison Données actionneur vs Modèle tfest');
    compare(data, sys_identifie); 
    grid on;
    title(['Comparaison Temporelle actionneur - Ordre ', num2str(npa)]);

end
disp(toc)