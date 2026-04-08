classdef InterfaceSimulink < matlab.apps.AppBase
    
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        
        % Onglets
        TabGroup                    matlab.ui.container.TabGroup
        TabAccueil                  matlab.ui.container.Tab
        TabCalibration              matlab.ui.container.Tab
        TabParametres               matlab.ui.container.Tab
        TabLame                     matlab.ui.container.Tab % NOUVEL ONGLET
        
        % --- Accueil ---
        RafrachirButton             matlab.ui.control.Button
        MassemesuregEditField       matlab.ui.control.NumericEditField
        MassemesuregEditFieldLabel  matlab.ui.control.Label
        EntreMassegEditField        matlab.ui.control.NumericEditField
        EntreMasseKgLabel           matlab.ui.control.Label
        ArrtersimulationButton      matlab.ui.control.Button
        DmarrersimulationButton     matlab.ui.control.Button
        ClearButton                 matlab.ui.control.Button
        TareButton                  matlab.ui.control.Button
        PositionmesureLabel         matlab.ui.control.Label
        PositionmesureEditField     matlab.ui.control.NumericEditField
        
        UIAxes                      matlab.ui.control.UIAxes 
        UIAxesPosition              matlab.ui.control.UIAxes 
        
        % --- Calibration ---
        DemarrerCalibButton         matlab.ui.control.Button
        InstructionCalibLabel       matlab.ui.control.Label
        CalibrationTable            matlab.ui.control.Table
        AcquerirPointButton         matlab.ui.control.Button
        CalculerCalibButton         matlab.ui.control.Button
        DegrePolyLabel              matlab.ui.control.Label
        DegrePolySpinner            matlab.ui.control.Spinner
        EquationLabel               matlab.ui.control.Label
        StableLamp                  matlab.ui.control.Lamp 
        StableLampLabel             matlab.ui.control.Label
        
        % --- Paramètres ---
        SectionParamLabel           matlab.ui.control.Label
        
        TitrePositionLabel          matlab.ui.control.Label
        KpPosLabel                  matlab.ui.control.Label
        KpPosEditField              matlab.ui.control.Spinner
        KiPosLabel                  matlab.ui.control.Label
        KiPosEditField              matlab.ui.control.Spinner
        KdPosLabel                  matlab.ui.control.Label
        KdPosEditField              matlab.ui.control.Spinner
        
        TitreCourantLabel           matlab.ui.control.Label
        KpCouLabel                  matlab.ui.control.Label
        KpCouEditField              matlab.ui.control.Spinner
        KiCouLabel                  matlab.ui.control.Label
        KiCouEditField              matlab.ui.control.Spinner
        
        TitreBitsLabel              matlab.ui.control.Label
        BitsADCLabel                matlab.ui.control.Label
        BitsADCEditField            matlab.ui.control.Spinner
        BitsDACLabel                matlab.ui.control.Label
        BitsDACEditField            matlab.ui.control.Spinner
        
        TitreCondPosLabel           matlab.ui.control.Label
        GainPosLabel                matlab.ui.control.Label
        GainPosEditField            matlab.ui.control.Spinner
        OffsetPosLabel              matlab.ui.control.Label
        OffsetPosEditField          matlab.ui.control.Spinner
        NumPosLabel                 matlab.ui.control.Label
        NumPosEditField             matlab.ui.control.EditField 
        DenPosLabel                 matlab.ui.control.Label
        DenPosEditField             matlab.ui.control.EditField 
        
        TitreCondCouLabel           matlab.ui.control.Label
        GainCouLabel                matlab.ui.control.Label
        GainCouEditField            matlab.ui.control.Spinner
        OffsetCouLabel              matlab.ui.control.Label
        OffsetCouEditField          matlab.ui.control.Spinner
        NumCouLabel                 matlab.ui.control.Label
        NumCouEditField             matlab.ui.control.EditField
        DenCouLabel                 matlab.ui.control.Label
        DenCouEditField             matlab.ui.control.EditField
        
        TitreCondPWMLabel           matlab.ui.control.Label
        GainPWMLabel                matlab.ui.control.Label
        GainPWMEditField            matlab.ui.control.Spinner
        OffsetPWMLabel              matlab.ui.control.Label
        OffsetPWMEditField          matlab.ui.control.Spinner
        NumPWMLabel                 matlab.ui.control.Label
        NumPWMEditField             matlab.ui.control.EditField
        DenPWMLabel                 matlab.ui.control.Label
        DenPWMEditField             matlab.ui.control.EditField
        
        % --- Paramètres Lame ---
        PanelLameInputs             matlab.ui.container.Panel
        
        LameLengthLabel             matlab.ui.control.Label
        LameLengthEditField         matlab.ui.control.NumericEditField
        LameWidthLabel              matlab.ui.control.Label
        LameWidthEditField          matlab.ui.control.NumericEditField
        LameThicknessLabel          matlab.ui.control.Label
        LameThicknessEditField      matlab.ui.control.NumericEditField
        
        LameMaterialLabel           matlab.ui.control.Label
        LameMaterialDropDown        matlab.ui.control.DropDown
        LameYoungLabel              matlab.ui.control.Label
        LameYoungEditField          matlab.ui.control.NumericEditField
        
        LameMasseEchelonLabel       matlab.ui.control.Label
        LameMasseEchelonEditField   matlab.ui.control.NumericEditField
        
        LancerAnalyseLameButton     matlab.ui.control.Button
        StatusLameLabel             matlab.ui.control.Label
        
        UIAxesLameSim               matlab.ui.control.UIAxes
        UIAxesCapteurDist           matlab.ui.control.UIAxes
        UIAxesFFT                   matlab.ui.control.UIAxes
    end
    
    properties (Access = private)
        PlotTimer                   
        LiveLine                    
        LiveLinePosition            
        TimeOffset = 0;             
        TareValue = 0;  
        LastTareTime = 0;              
        
        % Variables pour la sequence de calibration
        CalibDataMasses = [];
        CalibDataTensions = [];
        DerniereTensionLue = 0;
        
        % Séquence des masses demandées
        MassesCibles = [0, 1, 3, 5, 10, 20, 40, 50, 60, 80, 100];
        IndexCalibration = 1;
        EnCalibration = false;
        NomModele = 'Simulation_balance_poids_variable_realtime2024';
    end
    
    methods (Access = private)
        
        % Envoi des parametres vers le Workspace MATLAB
        function GainValueChanged(app, ~)
            try
                assignin('base', 'kp_pos', app.KpPosEditField.Value);
                assignin('base', 'ki_pos', app.KiPosEditField.Value);
                assignin('base', 'kd_pos', app.KdPosEditField.Value);
                assignin('base', 'kp_courant', app.KpCouEditField.Value);
                assignin('base', 'ki_courant', app.KiCouEditField.Value);
                
                assignin('base', 'bits_adc', app.BitsADCEditField.Value);
                assignin('base', 'bits_dac', app.BitsDACEditField.Value);
                
                assignin('base', 'gain_pos', app.GainPosEditField.Value);
                assignin('base', 'offset_pos', app.OffsetPosEditField.Value);
                assignin('base', 'num_pos', str2num(app.NumPosEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_pos', str2num(app.DenPosEditField.Value)); %#ok<ST2NM>
                
                assignin('base', 'gain_cou', app.GainCouEditField.Value);
                assignin('base', 'offset_cou', app.OffsetCouEditField.Value);
                assignin('base', 'num_cou', str2num(app.NumCouEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_cou', str2num(app.DenCouEditField.Value)); %#ok<ST2NM>
                
                assignin('base', 'gain_com', app.GainPWMEditField.Value);
                assignin('base', 'offset_com', app.OffsetPWMEditField.Value);
                assignin('base', 'num_com', str2num(app.NumPWMEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_com', str2num(app.DenPWMEditField.Value)); %#ok<ST2NM>
                
            catch ME
                disp(['Erreur param : ', ME.message]);
            end
        end
        
        % Mise a jour des graphiques ET de la LED
        function updatePlot(app)
            status = get_param(app.NomModele,'SimulationStatus');
            
            if strcmp(status, 'running')
                try
                    t_simulink = get_param(app.NomModele, 'SimulationTime');
                    t_continu = app.TimeOffset + t_simulink;
                    
                    % 1. Masse
                    rto_masse = get_param([app.NomModele, '/ScopeSortie'],'RuntimeObject');
                    if ~isempty(rto_masse)
                        val_masse = double(rto_masse.InputPort(1).Data) - app.TareValue;
                        app.LiveLine.XData = [app.LiveLine.XData, t_continu];
                        app.LiveLine.YData = [app.LiveLine.YData, val_masse];
                        app.MassemesuregEditField.Value = val_masse;
                        
                        if t_continu > app.UIAxes.XLim(2)
                            app.UIAxes.XLim = [0, t_continu + 2];
                        end
                    end
                    
                    % 2. Position
                    try
                        rto_pos = get_param([app.NomModele, '/ScopePosition'],'RuntimeObject');
                        if ~isempty(rto_pos)
                            val_pos = double(rto_pos.InputPort(1).Data);
                            app.LiveLinePosition.XData = [app.LiveLinePosition.XData, t_continu];
                            app.LiveLinePosition.YData = [app.LiveLinePosition.YData, val_pos];
                            
                            % --- NOUVEAU : Envoi de la valeur vers l'interface (en mm) ---
                            app.PositionmesureEditField.Value = val_pos * 1000;
                            
                            if t_continu > app.UIAxesPosition.XLim(2)
                                app.UIAxesPosition.XLim = [0, t_continu + 2];
                            end
                        end
                    catch
                    end
                    
                    % 3. Tension pour calibration
                    try
                        rto_tension = get_param([app.NomModele, '/ScopeTension'],'RuntimeObject');
                        if ~isempty(rto_tension)
                            app.DerniereTensionLue = double(rto_tension.InputPort(1).Data);
                        end
                    catch
                    end
                    
                    % 4. MISE À JOUR DE LA LED DE STABILITÉ
                    try
                        rto_stable = get_param([app.NomModele, '/MATLAB Function2'],'RuntimeObject');
                        if ~isempty(rto_stable)
                            val_stable = double(rto_stable.OutputPort(2).Data);
                            if val_stable >= 1
                                app.StableLamp.Color = [0 1 0]; % Vert (Stable)
                            else
                                app.StableLamp.Color = [1 0 0]; % Rouge (Instable)
                            end
                        end
                    catch
                    end
                    
                    drawnow limitrate; 
                catch
                end
            elseif strcmp(status, 'stopped')
                if isvalid(app.PlotTimer) && strcmp(app.PlotTimer.Running, 'on')
                    stop(app.PlotTimer);
                end
            end
        end
        
        function TareButtonPushed(app, ~)
            temps_actuel = now;
            % Calcule le délai en secondes depuis le dernier clic
            delai_secondes = (temps_actuel - app.LastTareTime) * 24 * 3600;
            
            if delai_secondes < 0.6 % Si double-clic (moins de 600 ms)
                % --- ANNULATION DE LA TARE ---
                % On redonne au graphique sa valeur absolue
                app.LiveLine.YData = app.LiveLine.YData + app.TareValue; 
                app.TareValue = 0; % On vide la mémoire de la tare
                app.LastTareTime = 0; % Reset pour éviter un triple-clic buggé
            else
                % --- TARE NORMALE ---
                valeur_actuelle = app.MassemesuregEditField.Value;
                app.TareValue = app.TareValue + valeur_actuelle;
                app.LiveLine.YData = app.LiveLine.YData - valeur_actuelle;
                app.MassemesuregEditField.Value = 0;
                
                % On enregistre l'heure de ce clic
                app.LastTareTime = temps_actuel; 
            end
        end
        
        function ArrtersimulationButtonPushed(app, ~)
            set_param(app.NomModele, 'SimulationCommand', 'stop');
            app.StableLamp.Color = [0.5 0.5 0.5]; % Gris quand arrêté
            if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                stop(app.PlotTimer);
            end
        end
        
        function RafrachirButtonPushed(app, ~)
            try
                % 1. Met la simulation sur pause (le PID reste actif et garde la lame en l'air !)
                set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'pause');
                
                % 2. Envoie la nouvelle masse directement dans le Workspace MATLAB
                nouvelle_masse = app.EntreMassegEditField.Value;
                assignin('base', 'masse_ui', nouvelle_masse);
                
                % 3. Met à jour les gains de l'interface
                GainValueChanged(app, []);
                
                % 4. Force Simulink à lire la nouvelle variable masse_ui
                set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'update');
                
                % 5. Relâche la pause instantanément
                set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'continue');
                
                % Relance le chronomètre d'affichage si besoin
                if strcmp(app.PlotTimer.Running, 'off')
                    start(app.PlotTimer);
                end
                
            catch ME
                % S'il y a une erreur, on l'affiche dans une fenêtre au lieu de la cacher !
                uialert(app.UIFigure, ['Erreur lors du rafraîchissement : ', ME.message], 'Erreur');
            end
        end
        
        function DmarrersimulationButtonPushed(app, ~)
            try
                % 1. On s'assure que le modèle est bien chargé en mémoire
                load_system(app.NomModele);
        
                % 2. On exécute ton script d'initialisation (génère les tables LPV, etc.)
                evalin('base', 'Initialisation_simulation'); 
                
                % 3. On envoie la masse initiale choisie dans l'UI vers le Workspace MATLAB
                % (Assure-toi que le bloc constant dans Simulink a bien "masse_ui" comme valeur)
                assignin('base', 'masse_ui', app.EntreMassegEditField.Value);
                
                % 4. On met à jour les paramètres PID et filtres
                GainValueChanged(app, []);
                
                % 5. On réinitialise les graphiques et les temps pour un nouveau départ
                app.TimeOffset = 0;
                app.LiveLine.XData = [];
                app.LiveLine.YData = [];
                app.UIAxes.XLim = [0 5]; 
                app.LiveLinePosition.XData = [];
                app.LiveLinePosition.YData = [];
                app.UIAxesPosition.XLim = [0 5]; 
                
                % 6. DÉMARRAGE DE LA SIMULATION
                set_param(app.NomModele, 'SimulationCommand', 'start');
                
                % 7. Gestion du chronomètre pour rafraîchir l'affichage
                if isempty(app.PlotTimer) || ~isvalid(app.PlotTimer)
                    app.PlotTimer = timer('ExecutionMode', 'fixedRate', ...
                                          'Period', 0.1, ...
                                          'TimerFcn', @(~,~)updatePlot(app));
                end
                
                if strcmp(app.PlotTimer.Running, 'off')
                    start(app.PlotTimer);
                end
                
            catch ME
                % S'il y a la moindre erreur, une fenêtre pop-up va s'afficher avec le détail !
                uialert(app.UIFigure, ['Erreur au démarrage : ', ME.message], 'Erreur de Démarrage');
            end
        end
      
        function ClearButtonPushed(app, ~)
            app.LiveLine.XData = [];
            app.LiveLine.YData = [];
            app.UIAxes.XLim = [0 5]; 
            
            app.LiveLinePosition.XData = [];
            app.LiveLinePosition.YData = [];
            app.UIAxesPosition.XLim = [0 5]; 
        end
        
        % =========================================================
        % SEQUENCE DE CALIBRATION INTELLIGENTE
        % =========================================================
        
        function DemarrerCalibPushed(app, ~)
            status = get_param(app.NomModele,'SimulationStatus');
            if ~strcmp(status, 'running') && ~strcmp(status, 'paused')
                uialert(app.UIFigure, 'Veuillez démarrer la simulation dans l''onglet Accueil avant de calibrer.', 'Simulation à l''arrêt');
                return;
            end
            app.CalibDataMasses = [];
            app.CalibDataTensions = [];
            app.IndexCalibration = 1;
            app.EnCalibration = true;
            
            app.CalibrationTable.Data = table([], [], 'VariableNames', {'Masse (g)', 'Tension brute lue'});
            app.EquationLabel.Text = 'Équation : (En attente)';
            
            % On place la première masse cible dans la case de l'UI
            masse_req = app.MassesCibles(app.IndexCalibration);
            app.EntreMassegEditField.Value = masse_req; 
            
            % APPEL AUTOMATIQUE : Déclenche la même logique que le bouton Rafraîchir
            RafrachirButtonPushed(app, []);
            
            app.InstructionCalibLabel.Text = sprintf('-> La masse de %d g est appliquée ! Enregistrez dès que la LED est VERTE.', masse_req);
            app.InstructionCalibLabel.FontColor = [0 0 0]; 
        end
        
        function AcquerirPointPushed(app, ~)
            if ~app.EnCalibration
                uialert(app.UIFigure, 'Veuillez cliquer sur "Démarrer Calibration" en premier.', 'Action requise');
                return;
            end
            
            masse_actuelle = app.MassesCibles(app.IndexCalibration);
            app.CalibDataMasses = [app.CalibDataMasses; masse_actuelle];
            app.CalibDataTensions = [app.CalibDataTensions; app.DerniereTensionLue];
            
            app.CalibrationTable.Data = table(app.CalibDataMasses, app.CalibDataTensions, ...
                'VariableNames', {'Masse (g)', 'Tension brute lue'});
            
            app.IndexCalibration = app.IndexCalibration + 1;
            
            if app.IndexCalibration > length(app.MassesCibles)
                app.EnCalibration = false;
                app.InstructionCalibLabel.Text = 'Calibration terminée ! Calcul en cours...';
                app.InstructionCalibLabel.FontColor = [0 0.5 0]; 
                
                CalculerCalibPushed(app, []);
            else
                % L'interface change la case masse TOUTE SEULE
                masse_suivante = app.MassesCibles(app.IndexCalibration);
                app.EntreMassegEditField.Value = masse_suivante;
                
                % APPEL AUTOMATIQUE : Déclenche la même logique que le bouton Rafraîchir
                RafrachirButtonPushed(app, []);
                
                app.InstructionCalibLabel.Text = sprintf('-> Succès ! La masse de %d g est appliquée. Attendez que la LED redevienne VERTE.', masse_suivante);
            end
        end
        
        function CalculerCalibPushed(app, ~)
            if length(app.CalibDataMasses) < 2
                uialert(app.UIFigure, 'Pas assez de données pour calibrer.', 'Erreur');
                return;
            end
            
            degre = app.DegrePolySpinner.Value;
            if length(app.CalibDataMasses) <= degre
                uialert(app.UIFigure, 'Le degré du polynôme est trop élevé pour le nombre de points.', 'Erreur');
                return;
            end
            
            calib_coeffs = polyfit(app.CalibDataTensions, app.CalibDataMasses, degre);
            
            eq_str = 'y = ';
            for i = 1:length(calib_coeffs)
                puissance = length(calib_coeffs) - i;
                if puissance > 0
                    eq_str = [eq_str, sprintf('%.4e * x^%d + ', calib_coeffs(i), puissance)];
                else
                    eq_str = [eq_str, sprintf('%.4e', calib_coeffs(i))];
                end
            end
            app.EquationLabel.Text = eq_str;
            
            assignin('base', 'calib_coeffs', calib_coeffs);
            
            status = get_param(app.NomModele,'SimulationStatus');
            if strcmp(status, 'running') || strcmp(status, 'paused')
                set_param(app.NomModele, 'SimulationCommand', 'pause');
                set_param(app.NomModele, 'SimulationCommand', 'update');
                set_param(app.NomModele, 'SimulationCommand', 'continue');
            end
            
            uialert(app.UIFigure, 'La calibration est terminée ! Les nouveaux coefficients sont dans le Workspace.', 'Succès');
        end
        
        % =========================================================
        % ONGLET 4 : ANALYSE DE LA LAME
        % =========================================================
        
        function MateriauDropdownValueChanged(app, ~)
            val = app.LameMaterialDropDown.Value;
            switch val
                case 'Fibre de verre (FR4)'
                    app.LameYoungEditField.Value = 18.6e9;
                case 'Aluminium'
                    app.LameYoungEditField.Value = 69e9;
                case 'Acier'
                    app.LameYoungEditField.Value = 200e9;
                case 'Personnalisé'
                    % L'utilisateur entre sa propre valeur
            end
        end
        
        function LancerAnalyseLamePushed(app, ~)
            % Désactiver le bouton pendant le calcul
            app.LancerAnalyseLameButton.Enable = 'off';
            app.StatusLameLabel.Text = 'Simulation en cours... Veuillez patienter.';
            app.StatusLameLabel.FontColor = [1 0 0];
            drawnow;
            
            try
                % --- Récupération des paramètres UI ---
                L = app.LameLengthEditField.Value;
                b = app.LameWidthEditField.Value;
                h = app.LameThicknessEditField.Value;
                E = app.LameYoungEditField.Value;
                masse_echelon_g = app.LameMasseEchelonEditField.Value;
                
                % --- Paramètres Fixes (Similaires au script original) ---
                masse = 61/1000; % masse actionneur kg
                masse_aimant = 1/1000; % masse aimant kg
                pos_actionneur = 0.1345; % m
                c = 0.35443;
                g = 9.81;
                Force_echelon = -(masse_echelon_g / 1000) * g;
                
                dens = 1850; % Densité Kg/m^3 (approx générique, modifiable)
                mu = dens*b*h;
                J = b*h^3/12;
                
                nx = 10;
                dt = 3e-5;
                temps_simulation = 15; % Augmenté à 15s pour mieux voir l'amortissement
                nt = round(temps_simulation/dt);
                
                dx = L/(nx-1);
                dx_n = dx/L;
                idx_force = round(pos_actionneur / dx) + 2;
                idx_bout = round(L / dx) + 2;
                
                % Masse effective
                mu_eff = mu * ones(1, nx);
                mu_eff_intrinseque = mu_eff;
                mu_eff(idx_force) = mu_eff(idx_force) + (masse / dx);
                mu_eff(nx) = mu_eff(nx) + (masse_aimant / dx);
                
                kappa_eff = sqrt(E*J ./ (mu_eff * L^4));
                mu_simu_eff = kappa_eff * dt / dx_n^2;
                
                % Coeffs
                coeff1 = (2 - 6 * mu_simu_eff.^2);
                coeff2 = (4 * mu_simu_eff.^2);
                coeff3 = -mu_simu_eff.^2;
                
                alpha = (c * dt) ./ (mu_eff * 2);
                Facteur_a1 = 1 ./ (alpha + 1);
                Facteur_a2 = (alpha - 1) ./ (alpha + 1);
                
                coeff1_a = coeff1 .* Facteur_a1; 
                coeff2_a = coeff2 .* Facteur_a1;
                coeff3_a = coeff3 .* Facteur_a1;
                effet_gravite_a = (-g * dt^2) .* Facteur_a1;
                facteur_force_eff = (dt^2 ./ (mu_eff *dx)) .* Facteur_a1;
                
                % Force
                F = zeros(1, nt+50);
                F(1:end) = Force_echelon; 
                
                x  = -dx:dx:L+dx;
                nx = nx+2;
                
                % Init statique avec masse (calcul_pos_repos_avec_masses = true)
                K = zeros(nx, nx);
                B = zeros(nx, 1);
                for i = 3:nx-2
                    K(i, i-2) = -coeff3_a(i); K(i, i-1) = -coeff2_a(i); K(i, i) = 1 - coeff1_a(i) - Facteur_a2(i); K(i, i+1) = -coeff2_a(i); K(i, i+2) = -coeff3_a(i);
                    B(i) = effet_gravite_a(i);
                end
                K(1, 1) = 1; B(1) = 0; K(2, 2) = 1; B(2) = 0;
                K(nx-1, nx-3) = 1; K(nx-1, nx-2) = -2; K(nx-1, nx-1) = 1; B(nx-1) = 0;
                K(nx, nx-2)   = 1; K(nx, nx-1)   = -2; K(nx, nx)   = 1; B(nx)   = 0;
                
                w = (K \ B)'; 
                w_repos = w;
                z_capteur = w_repos(idx_force) - 0.0075;
                
                w_old = w; w_new = zeros(1,nx); w_init = w;
                pos_bout = zeros(1,nt+1); pos_actionneur = zeros(1,nt+1);
                
                % Préparation Figure Lame (UIAxesLameSim)
                cla(app.UIAxesLameSim);
                hold(app.UIAxesLameSim, 'on');
                plot(app.UIAxesLameSim, x, 1000*w_init, 'k--', 'DisplayName', 'Repos');
                h_line = plot(app.UIAxesLameSim, x, 1000*w_new, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Dynamique');
                plot(app.UIAxesLameSim, x(idx_force), 0, 'g.', 'MarkerSize', 15);
                ylim(app.UIAxesLameSim, [-15, 5]);
                grid(app.UIAxesLameSim, 'on');
                title(app.UIAxesLameSim, 'Simulation physique de la lame');
                xlabel(app.UIAxesLameSim, 'x [m]'); ylabel(app.UIAxesLameSim, 'Déflexion [mm]');
                
                i_interne = 3:nx-2; 
                w_new = w; 
                
                % Boucle
                for n = 0:nt 
                    w_new(i_interne) = coeff1_a(i_interne).*w(i_interne) + ...
                                       coeff2_a(i_interne).*(w(i_interne+1)+w(i_interne-1)) + ...
                                       coeff3_a(i_interne).*(w(i_interne+2)+w(i_interne-2)) + ...
                                       w_old(i_interne).*Facteur_a2(i_interne) + effet_gravite_a(i_interne);
                    
                    w_new(idx_force) = w_new(idx_force) + (F(n+1) * facteur_force_eff(idx_force));
                    w_new(1:2) = 0;                 
                    w_new(end-1) = 2*w_new(end-2) - w_new(end-3);    
                    w_new(end) = 2*w_new(end-1) - w_new(end-2);
                    
                    w_old = w; w = w_new;
                    pos_bout(n+1) = w(end);
                    pos_actionneur(n+1) = w(idx_force); 
                    
                    % Affichage dynamique (rafraîchissement ajusté pour la vitesse avec nt plus grand)
                    if mod(n, 4000) == 0
                        h_line.YData = 1000 * w_new;
                        drawnow limitrate;
                    end
                end
                
                % Distance capteur
                distance_capteur = pos_actionneur - z_capteur;
                t_vec = (0:dt:(nt*dt));
                
                cla(app.UIAxesCapteurDist);
                plot(app.UIAxesCapteurDist, t_vec, distance_capteur * 1000, 'r');
                grid(app.UIAxesCapteurDist, 'on');
                title(app.UIAxesCapteurDist, 'Distance mesurée par capteur');
                xlabel(app.UIAxesCapteurDist, 'Temps (s)'); ylabel(app.UIAxesCapteurDist, 'Distance (mm)');
                
                % --- AJOUT DE LA LIMITE Y POUR 0g ---
                if masse_echelon_g == 0
                    ylim(app.UIAxesCapteurDist, [7.0, 8.0]);
                else
                    ylim(app.UIAxesCapteurDist, 'auto');
                end
                % ------------------------------------
                
                % FFT
                pos_repos_fft = mean(pos_bout(round(nt/2):end)); % Utiliser la 2e moitié pour la moyenne
                h_fft = pos_bout - pos_repos_fft; 
                Fs = 1/dt;               
                L_sig = length(h_fft);       
                Y = fft(h_fft);
                P2 = abs(Y/L_sig);
                P1 = 20 * log10(P2(1:floor(L_sig/2)+1));
                P1(2:end-1) = 2*P1(2:end-1); 
                f_fft = Fs*(0:floor(L_sig/2))/L_sig;
                
                cla(app.UIAxesFFT);
                plot(app.UIAxesFFT, f_fft, P1, 'b-');
                xlim(app.UIAxesFFT, [0, 100]); % Limite de l'axe des X modifiée
                grid(app.UIAxesFFT, 'on');
                title(app.UIAxesFFT, 'Spectre (FFT) de l''extrémité');
                xlabel(app.UIAxesFFT, 'Fréquence (Hz)'); ylabel(app.UIAxesFFT, 'Amplitude');
                
                app.StatusLameLabel.Text = 'Simulation terminée avec succès !';
                app.StatusLameLabel.FontColor = [0 0.5 0];
                
            catch ME
                app.StatusLameLabel.Text = 'Erreur lors de la simulation.';
                uialert(app.UIFigure, ['Erreur : ', ME.message], 'Erreur Simulation');
            end
            
            app.LancerAnalyseLameButton.Enable = 'on';
        end

       % --- 1. FONCTION POUR LANCER LA SIMULATION FEMM ---
        function GenererDonneesFEMMPushed(app, ~)
            app.StatusLameLabel.Text = 'Génération FEMM en cours... Patientez.';
            app.StatusLameLabel.FontColor = [1 0.5 0]; 
            drawnow;
            
            try
                dossier_actuel = pwd;
                chemin_femm_folder = fullfile(pwd, '..', 'FEMM');
                cd(chemin_femm_folder);
                
                chemin_executable_femm = 'C:\femm42\bin\femm.exe'; % Vérifie que c'est bien le chemin sur ton PC
                nom_script_lua = 'code_analyse_V2.lua'; % TON FICHIER LUA ICI
                
                commande = sprintf('"%s" -windowhide -lua "%s"', chemin_executable_femm, nom_script_lua);
                status = system(commande);
                
                cd(dossier_actuel);
                
                if status == 0
                    app.StatusLameLabel.Text = 'Génération terminée !';
                    app.StatusLameLabel.FontColor = [0 0.5 0]; 
                    ChargerLUTPushed(app, []); 
                else
                    error('Erreur lors de l''exécution de FEMM (code %d).', status);
                end
                
            catch ME
                cd(dossier_actuel); 
                app.StatusLameLabel.Text = 'Erreur lors de la génération FEMM.';
                app.StatusLameLabel.FontColor = [1 0 0];
                uialert(app.UIFigure, ['Erreur : ', ME.message], 'Erreur FEMM');
            end
        end
        
        % --- 2. FONCTION POUR LIRE LES DONNÉES GÉNÉRÉES ---
        function ChargerLUTPushed(app, ~)
            try
                % TON FICHIER TEXTE ICI
                fichier_lut = fullfile(pwd, '..', 'FEMM', 'LUT_main_V2.txt'); 
                
                if ~isfile(fichier_lut)
                    error('Le fichier LUT_main_V2.txt est introuvable.');
                end
                
                opts = detectImportOptions(fichier_lut);
                donnees_femm = readtable(fichier_lut, opts);
                
                position_m = donnees_femm.x_m;        
                inductance_Lb = donnees_femm.Lb_H_;   
                force_Kb = donnees_femm.Kb_N_A_;      
                
                assignin('base', 'LUT_position', position_m);
                assignin('base', 'LUT_inductance', inductance_Lb);
                assignin('base', 'LUT_force', force_Kb);
                
                uialert(app.UIFigure, 'Les données FEMM ont été chargées avec succès !', 'Succès');
                
            catch ME
                uialert(app.UIFigure, ['Erreur de lecture : ', ME.message], 'Erreur');
            end
        end
    end
    
    methods (Access = private)
        function createComponents(app)
            % FENÊTRE
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1200 850]; 
            app.UIFigure.Name = 'Interface Centre de Contrôle';
            
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [0 0 1200 850];
            
            % --- ONGLET 1 : ACCUEIL ---
            app.TabAccueil = uitab(app.TabGroup);
            app.TabAccueil.Title = '1. Accueil (Mesures)';
            
            app.UIAxes = uiaxes(app.TabAccueil);
            title(app.UIAxes, 'Masse mesurée (g) selon le temps (s)')
            xlabel(app.UIAxes, 'Temps (s)')
            ylabel(app.UIAxes, 'Masse mesurée (g)')
            app.UIAxes.Position = [20 450 650 350]; 
            grid(app.UIAxes, 'on'); hold(app.UIAxes, 'on');
            app.LiveLine = plot(app.UIAxes, NaN, NaN, 'b-', 'LineWidth', 1.5);
            
            app.UIAxesPosition = uiaxes(app.TabAccueil);
            title(app.UIAxesPosition, 'Position de la lame (m) selon le temps (s)')
            xlabel(app.UIAxesPosition, 'Temps (s)')
            ylabel(app.UIAxesPosition, 'Position (m)')
            app.UIAxesPosition.Position = [20 50 650 350];
            grid(app.UIAxesPosition, 'on'); hold(app.UIAxesPosition, 'on');
            app.LiveLinePosition = plot(app.UIAxesPosition, NaN, NaN, 'r-', 'LineWidth', 1.5);
            
            X_mid = 750;
            app.DmarrersimulationButton = uibutton(app.TabAccueil, 'push');
            app.DmarrersimulationButton.ButtonPushedFcn = createCallbackFcn(app, @DmarrersimulationButtonPushed, true);
            app.DmarrersimulationButton.Position = [X_mid 700 200 50];
            app.DmarrersimulationButton.Text = 'Démarrer simulation';
            app.DmarrersimulationButton.BackgroundColor = [0.47 0.87 0.47];
            
            app.ArrtersimulationButton = uibutton(app.TabAccueil, 'push');
            app.ArrtersimulationButton.ButtonPushedFcn = createCallbackFcn(app, @ArrtersimulationButtonPushed, true);
            app.ArrtersimulationButton.Position = [X_mid 630 200 50];
            app.ArrtersimulationButton.Text = 'Arrêter simulation';
            app.ArrtersimulationButton.BackgroundColor = [0.87 0.47 0.47];
            
            app.ClearButton = uibutton(app.TabAccueil, 'push');
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            app.ClearButton.Position = [X_mid 560 200 40]; 
            app.ClearButton.Text = 'Effacer graphiques';
            
            app.EntreMasseKgLabel = uilabel(app.TabAccueil);
            app.EntreMasseKgLabel.Position = [X_mid 480 200 22];
            app.EntreMasseKgLabel.Text = 'Entrée Masse Simulée (g) :';
            
            app.EntreMassegEditField = uieditfield(app.TabAccueil, 'numeric');
            app.EntreMassegEditField.Position = [X_mid 450 200 35];
            
            app.MassemesuregEditFieldLabel = uilabel(app.TabAccueil);
            app.MassemesuregEditFieldLabel.Position = [X_mid 380 200 22];
            app.MassemesuregEditFieldLabel.Text = 'Masse mesurée finale (g) :';
            
            app.MassemesuregEditField = uieditfield(app.TabAccueil, 'numeric');
            app.MassemesuregEditField.Editable = 'off';
            app.MassemesuregEditField.Position = [X_mid 340 200 40];
            app.MassemesuregEditField.FontSize = 18;
            app.MassemesuregEditField.FontWeight = 'bold';
            app.MassemesuregEditField.BackgroundColor = [0.9 0.9 0.9];
            
            % --- NOUVEAU : Affichage de la position ---
            app.PositionmesureLabel = uilabel(app.TabAccueil);
            app.PositionmesureLabel.Position = [X_mid 310 200 22];
            app.PositionmesureLabel.Text = 'Position mesurée (mm) :';
            
            app.PositionmesureEditField = uieditfield(app.TabAccueil, 'numeric');
            app.PositionmesureEditField.Editable = 'off';
            app.PositionmesureEditField.Position = [X_mid 270 200 40];
            app.PositionmesureEditField.FontSize = 18;
            app.PositionmesureEditField.FontWeight = 'bold';
            app.PositionmesureEditField.BackgroundColor = [0.9 0.9 0.9];
            app.PositionmesureEditField.ValueDisplayFormat = '%.3f'; 
            
            % --- BOUTONS DÉCALÉS ---
            app.TareButton = uibutton(app.TabAccueil, 'push');
            app.TareButton.ButtonPushedFcn = createCallbackFcn(app, @TareButtonPushed, true);
            app.TareButton.Position = [X_mid 200 200 40]; 
            app.TareButton.Text = 'Tare (0)';
            
            app.RafrachirButton = uibutton(app.TabAccueil, 'push');
            app.RafrachirButton.ButtonPushedFcn = createCallbackFcn(app, @RafrachirButtonPushed, true);
            app.RafrachirButton.Position = [X_mid 140 200 40]; 
            app.RafrachirButton.Text = 'Rafraîchir Simulink';
            app.RafrachirButton.BackgroundColor = [0.6 0.8 1.0];
            
            
            % --- ONGLET 2 : CALIBRATION ---
            app.TabCalibration = uitab(app.TabGroup);
            app.TabCalibration.Title = '2. Calibration';
            
            app.DemarrerCalibButton = uibutton(app.TabCalibration, 'push');
            app.DemarrerCalibButton.Position = [50 750 200 40];
            app.DemarrerCalibButton.Text = '1. Démarrer Calibration';
            app.DemarrerCalibButton.ButtonPushedFcn = createCallbackFcn(app, @DemarrerCalibPushed, true);
            
            app.InstructionCalibLabel = uilabel(app.TabCalibration);
            app.InstructionCalibLabel.Position = [280 750 800 40];
            app.InstructionCalibLabel.FontSize = 14;
            app.InstructionCalibLabel.FontWeight = 'bold';
            app.InstructionCalibLabel.Text = 'Cliquez sur Démarrer pour lancer la séquence.';
            
            app.StableLampLabel = uilabel(app.TabCalibration);
            app.StableLampLabel.Position = [500 700 200 22];
            app.StableLampLabel.FontWeight = 'bold';
            app.StableLampLabel.Text = 'État de la mesure :';
            
            app.StableLamp = uilamp(app.TabCalibration);
            app.StableLamp.Position = [620 700 20 20];
            app.StableLamp.Color = [0.5 0.5 0.5]; 
            
            app.CalibrationTable = uitable(app.TabCalibration);
            app.CalibrationTable.Position = [50 300 400 400];
            app.CalibrationTable.ColumnName = {'Masse (g)', 'Tension brute lue'};
            
            app.AcquerirPointButton = uibutton(app.TabCalibration, 'push');
            app.AcquerirPointButton.Position = [500 600 250 50];
            app.AcquerirPointButton.Text = '2. Enregistrer la mesure';
            app.AcquerirPointButton.BackgroundColor = [0.6 0.8 1.0];
            app.AcquerirPointButton.ButtonPushedFcn = createCallbackFcn(app, @AcquerirPointPushed, true);
            
            app.DegrePolyLabel = uilabel(app.TabCalibration);
            app.DegrePolyLabel.Position = [500 550 200 22];
            app.DegrePolyLabel.Text = 'Degré du polynôme :';
            
            app.DegrePolySpinner = uispinner(app.TabCalibration);
            app.DegrePolySpinner.Position = [500 520 100 30];
            app.DegrePolySpinner.Value = 1;
            app.DegrePolySpinner.Limits = [1 5];
            
            app.CalculerCalibButton = uibutton(app.TabCalibration, 'push');
            app.CalculerCalibButton.Position = [500 450 250 50];
            app.CalculerCalibButton.Text = 'Recalculer manuellement';
            app.CalculerCalibButton.ButtonPushedFcn = createCallbackFcn(app, @CalculerCalibPushed, true);
            
            app.EquationLabel = uilabel(app.TabCalibration);
            app.EquationLabel.Position = [50 250 800 30];
            app.EquationLabel.FontWeight = 'bold';
            app.EquationLabel.Text = 'Équation : (Aucune calibration)';
            
            
            % --- ONGLET 3 : PARAMÈTRES ---
            app.TabParametres = uitab(app.TabGroup);
            app.TabParametres.Title = '3. Paramètres avancés';
            
            Col1 = 50; Val1 = 150;
            Col2 = 400; Val2 = 500;
            
            app.SectionParamLabel = uilabel(app.TabParametres);
            app.SectionParamLabel.Position = [Col1 780 400 25];
            app.SectionParamLabel.FontWeight = 'bold';
            app.SectionParamLabel.FontSize = 16;
            app.SectionParamLabel.Text = 'Paramètres de l''architecture et Régulateurs';
            
            % Régulateur Position
            app.TitrePositionLabel = uilabel(app.TabParametres); app.TitrePositionLabel.Position = [Col1 730 200 22]; app.TitrePositionLabel.FontWeight = 'bold'; app.TitrePositionLabel.Text = 'Régulateur Position';
            app.KpPosLabel = uilabel(app.TabParametres); app.KpPosLabel.Position = [Col1 700 80 22]; app.KpPosLabel.Text = 'Kp :';
            app.KpPosEditField = uispinner(app.TabParametres); app.KpPosEditField.Position = [Val1 700 90 22]; app.KpPosEditField.Value = 2.325; app.KpPosEditField.Step = 0.1; app.KpPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.KiPosLabel = uilabel(app.TabParametres); app.KiPosLabel.Position = [Col1 670 80 22]; app.KiPosLabel.Text = 'Ki :';
            app.KiPosEditField = uispinner(app.TabParametres); app.KiPosEditField.Position = [Val1 670 90 22]; app.KiPosEditField.Value = -27.5; app.KiPosEditField.Step = 0.5; app.KiPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.KdPosLabel = uilabel(app.TabParametres); app.KdPosLabel.Position = [Col1 640 80 22]; app.KdPosLabel.Text = 'Kd :';
            app.KdPosEditField = uispinner(app.TabParametres); app.KdPosEditField.Position = [Val1 640 90 22]; app.KdPosEditField.Value = -0.207; app.KdPosEditField.Step = 0.01; app.KdPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % Régulateur Courant
            app.TitreCourantLabel = uilabel(app.TabParametres); app.TitreCourantLabel.Position = [Col1 590 200 22]; app.TitreCourantLabel.FontWeight = 'bold'; app.TitreCourantLabel.Text = 'Régulateur Courant';
            app.KpCouLabel = uilabel(app.TabParametres); app.KpCouLabel.Position = [Col1 560 80 22]; app.KpCouLabel.Text = 'Kp :';
            app.KpCouEditField = uispinner(app.TabParametres); app.KpCouEditField.Position = [Val1 560 90 22]; app.KpCouEditField.Value = -0.575; app.KpCouEditField.Step = 0.05; app.KpCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.KiCouLabel = uilabel(app.TabParametres); app.KiCouLabel.Position = [Col1 530 80 22]; app.KiCouLabel.Text = 'Ki :';
            app.KiCouEditField = uispinner(app.TabParametres); app.KiCouEditField.Position = [Val1 530 90 22]; app.KiCouEditField.Value = -325; app.KiCouEditField.Step = 5; app.KiCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % Résolution
            app.TitreBitsLabel = uilabel(app.TabParametres); app.TitreBitsLabel.Position = [Col1 480 200 22]; app.TitreBitsLabel.FontWeight = 'bold'; app.TitreBitsLabel.Text = 'Résolution (Bits)';
            app.BitsADCLabel = uilabel(app.TabParametres); app.BitsADCLabel.Position = [Col1 450 80 22]; app.BitsADCLabel.Text = 'ADC :';
            app.BitsADCEditField = uispinner(app.TabParametres); app.BitsADCEditField.Position = [Val1 450 90 22]; app.BitsADCEditField.Value = 12; app.BitsADCEditField.Step = 1; app.BitsADCEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.BitsDACLabel = uilabel(app.TabParametres); app.BitsDACLabel.Position = [Col1 420 80 22]; app.BitsDACLabel.Text = 'DAC :';
            app.BitsDACEditField = uispinner(app.TabParametres); app.BitsDACEditField.Position = [Val1 420 90 22]; app.BitsDACEditField.Value = 12; app.BitsDACEditField.Step = 1; app.BitsDACEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % Cond. Acquisition Position
            app.TitreCondPosLabel = uilabel(app.TabParametres); app.TitreCondPosLabel.Position = [Col2 730 200 22]; app.TitreCondPosLabel.FontWeight = 'bold'; app.TitreCondPosLabel.Text = 'Cond. Acquisition (Position)';
            app.GainPosLabel = uilabel(app.TabParametres); app.GainPosLabel.Position = [Col2 700 80 22]; app.GainPosLabel.Text = 'Gain :';
            app.GainPosEditField = uispinner(app.TabParametres); app.GainPosEditField.Position = [Val2 700 90 22]; app.GainPosEditField.Value = 1.4925; app.GainPosEditField.Step = 0.1; app.GainPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.OffsetPosLabel = uilabel(app.TabParametres); app.OffsetPosLabel.Position = [Col2 670 80 22]; app.OffsetPosLabel.Text = 'Offset :';
            app.OffsetPosEditField = uispinner(app.TabParametres); app.OffsetPosEditField.Position = [Val2 670 90 22]; app.OffsetPosEditField.Value = -1.6; app.OffsetPosEditField.Step = 0.1; app.OffsetPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.NumPosLabel = uilabel(app.TabParametres); app.NumPosLabel.Position = [Col2 640 80 22]; app.NumPosLabel.Text = 'Filtre Num :';
            app.NumPosEditField = uieditfield(app.TabParametres, 'text'); app.NumPosEditField.Position = [Val2 640 150 22]; app.NumPosEditField.Value = '[1]'; app.NumPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.DenPosLabel = uilabel(app.TabParametres); app.DenPosLabel.Position = [Col2 610 80 22]; app.DenPosLabel.Text = 'Filtre Den :';
            app.DenPosEditField = uieditfield(app.TabParametres, 'text'); app.DenPosEditField.Position = [Val2 610 150 22]; app.DenPosEditField.Value = '[1/(2*pi*80) 1]'; app.DenPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % Cond. Acquisition Courant
            app.TitreCondCouLabel = uilabel(app.TabParametres); app.TitreCondCouLabel.Position = [Col2 560 200 22]; app.TitreCondCouLabel.FontWeight = 'bold'; app.TitreCondCouLabel.Text = 'Cond. Acquisition (Courant)';
            app.GainCouLabel = uilabel(app.TabParametres); app.GainCouLabel.Position = [Col2 530 80 22]; app.GainCouLabel.Text = 'Gain :';
            app.GainCouEditField = uispinner(app.TabParametres); app.GainCouEditField.Position = [Val2 530 90 22]; app.GainCouEditField.Value = 0.716; app.GainCouEditField.Step = 0.1; app.GainCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.OffsetCouLabel = uilabel(app.TabParametres); app.OffsetCouLabel.Position = [Col2 500 80 22]; app.OffsetCouLabel.Text = 'Offset :';
            app.OffsetCouEditField = uispinner(app.TabParametres); app.OffsetCouEditField.Position = [Val2 500 90 22]; app.OffsetCouEditField.Value = 3.44; app.OffsetCouEditField.Step = 0.1; app.OffsetCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.NumCouLabel = uilabel(app.TabParametres); app.NumCouLabel.Position = [Col2 470 80 22]; app.NumCouLabel.Text = 'Filtre Num :';
            app.NumCouEditField = uieditfield(app.TabParametres, 'text'); app.NumCouEditField.Position = [Val2 470 150 22]; app.NumCouEditField.Value = '[1]'; app.NumCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.DenCouLabel = uilabel(app.TabParametres); app.DenCouLabel.Position = [Col2 440 80 22]; app.DenCouLabel.Text = 'Filtre Den :';
            app.DenCouEditField = uieditfield(app.TabParametres, 'text'); app.DenCouEditField.Position = [Val2 440 150 22]; app.DenCouEditField.Value = '[1/(2*pi*165) 1]'; app.DenCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % Cond. Commande PWM
            app.TitreCondPWMLabel = uilabel(app.TabParametres); app.TitreCondPWMLabel.Position = [Col2 390 200 22]; app.TitreCondPWMLabel.FontWeight = 'bold'; app.TitreCondPWMLabel.Text = 'Cond. Commande (PWM)';
            app.GainPWMLabel = uilabel(app.TabParametres); app.GainPWMLabel.Position = [Col2 360 80 22]; app.GainPWMLabel.Text = 'Gain :';
            app.GainPWMEditField = uispinner(app.TabParametres); app.GainPWMEditField.Position = [Val2 360 90 22]; app.GainPWMEditField.Value = 0.88; app.GainPWMEditField.Step = 0.1; app.GainPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.OffsetPWMLabel = uilabel(app.TabParametres); app.OffsetPWMLabel.Position = [Col2 330 80 22]; app.OffsetPWMLabel.Text = 'Offset :';
            app.OffsetPWMEditField = uispinner(app.TabParametres); app.OffsetPWMEditField.Position = [Val2 330 90 22]; app.OffsetPWMEditField.Value = -2.5; app.OffsetPWMEditField.Step = 0.1; app.OffsetPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.NumPWMLabel = uilabel(app.TabParametres); app.NumPWMLabel.Position = [Col2 300 80 22]; app.NumPWMLabel.Text = 'Filtre Num :';
            app.NumPWMEditField = uieditfield(app.TabParametres, 'text'); app.NumPWMEditField.Position = [Val2 300 150 22]; app.NumPWMEditField.Value = '[1]'; app.NumPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            app.DenPWMLabel = uilabel(app.TabParametres); app.DenPWMLabel.Position = [Col2 270 80 22]; app.DenPWMLabel.Text = 'Filtre Den :';
            app.DenPWMEditField = uieditfield(app.TabParametres, 'text'); app.DenPWMEditField.Position = [Val2 270 150 22]; app.DenPWMEditField.Value = '[5900^2*1e-7^2 3*5900*1e-7 1]'; app.DenPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % =========================================================
            % ONGLET 4 : PARAMÈTRES LAME
            % =========================================================
            app.TabLame = uitab(app.TabGroup);
            app.TabLame.Title = '4. Paramètres lame';
            
            % --- Panneau de contrôle gauche ---
            app.PanelLameInputs = uipanel(app.TabLame);
            app.PanelLameInputs.Title = 'Dimensions & Matériau';
            app.PanelLameInputs.FontWeight = 'bold';
            app.PanelLameInputs.Position = [20 20 300 780];
            
            app.LameLengthLabel = uilabel(app.PanelLameInputs); app.LameLengthLabel.Position = [10 710 100 22]; app.LameLengthLabel.Text = 'Longueur L (m) :';
            app.LameLengthEditField = uieditfield(app.PanelLameInputs, 'numeric'); app.LameLengthEditField.Position = [130 710 150 22]; app.LameLengthEditField.Value = 24.3e-2; app.LameLengthEditField.ValueDisplayFormat = '%.4f';
            
            app.LameWidthLabel = uilabel(app.PanelLameInputs); app.LameWidthLabel.Position = [10 670 100 22]; app.LameWidthLabel.Text = 'Largeur b (m) :';
            app.LameWidthEditField = uieditfield(app.PanelLameInputs, 'numeric'); app.LameWidthEditField.Position = [130 670 150 22]; app.LameWidthEditField.Value = 7.08e-2; app.LameWidthEditField.ValueDisplayFormat = '%.4f';
            
            app.LameThicknessLabel = uilabel(app.PanelLameInputs); app.LameThicknessLabel.Position = [10 630 110 22]; app.LameThicknessLabel.Text = 'Épaisseur h (m) :';
            app.LameThicknessEditField = uieditfield(app.PanelLameInputs, 'numeric'); app.LameThicknessEditField.Position = [130 630 150 22]; app.LameThicknessEditField.Value = 1.5875e-3; app.LameThicknessEditField.ValueDisplayFormat = '%.5f';
            
            app.LameMaterialLabel = uilabel(app.PanelLameInputs); app.LameMaterialLabel.Position = [10 570 100 22]; app.LameMaterialLabel.Text = 'Matériau :';
            app.LameMaterialDropDown = uidropdown(app.PanelLameInputs); app.LameMaterialDropDown.Position = [130 570 150 22]; 
            app.LameMaterialDropDown.Items = {'Fibre de verre (FR4)', 'Aluminium', 'Acier', 'Personnalisé'};
            app.LameMaterialDropDown.ValueChangedFcn = createCallbackFcn(app, @MateriauDropdownValueChanged, true);
            
            app.LameYoungLabel = uilabel(app.PanelLameInputs); app.LameYoungLabel.Position = [10 530 110 22]; app.LameYoungLabel.Text = 'Mod. Young E (Pa) :';
            app.LameYoungEditField = uieditfield(app.PanelLameInputs, 'numeric'); app.LameYoungEditField.Position = [130 530 150 22]; app.LameYoungEditField.Value = 18.6e9; app.LameYoungEditField.ValueDisplayFormat = '%0.2e';
            
            app.LameMasseEchelonLabel = uilabel(app.PanelLameInputs); app.LameMasseEchelonLabel.Position = [10 470 120 22]; app.LameMasseEchelonLabel.Text = 'Masse (g) :';
            app.LameMasseEchelonLabel.Tooltip = 'Masse ajoutée instantanément pour exciter la lame et voir ses fréquences de résonance.';
            app.LameMasseEchelonEditField = uieditfield(app.PanelLameInputs, 'numeric'); app.LameMasseEchelonEditField.Position = [130 470 150 22]; app.LameMasseEchelonEditField.Value = 50; 
            
            app.LancerAnalyseLameButton = uibutton(app.PanelLameInputs, 'push');
            app.LancerAnalyseLameButton.Position = [30 380 230 50];
            app.LancerAnalyseLameButton.Text = 'Lancer Analyse Lame';
            app.LancerAnalyseLameButton.BackgroundColor = [0.4 0.6 0.9];
            app.LancerAnalyseLameButton.FontWeight = 'bold';
            app.LancerAnalyseLameButton.ButtonPushedFcn = createCallbackFcn(app, @LancerAnalyseLamePushed, true);
            
            app.StatusLameLabel = uilabel(app.PanelLameInputs);
            app.StatusLameLabel.Position = [30 350 230 22];
            app.StatusLameLabel.Text = 'Prêt.';
            app.StatusLameLabel.HorizontalAlignment = 'center';
            
            % --- Graphiques Lame ---
            app.UIAxesLameSim = uiaxes(app.TabLame);
            app.UIAxesLameSim.Position = [350 450 800 350];
            title(app.UIAxesLameSim, 'Simulation physique de la lame');
            
            app.UIAxesCapteurDist = uiaxes(app.TabLame);
            app.UIAxesCapteurDist.Position = [350 50 380 380];
            title(app.UIAxesCapteurDist, 'Distance mesurée par capteur');
            
            app.UIAxesFFT = uiaxes(app.TabLame);
            app.UIAxesFFT.Position = [770 50 380 380];
            title(app.UIAxesFFT, 'Spectre (FFT)');
            
            app.UIFigure.Visible = 'on';
        end
    end
    
    methods (Access = public)
        function app = InterfaceSimulink
            createComponents(app)
            registerApp(app, app.UIFigure)
        end
        function delete(app)
            if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                stop(app.PlotTimer);
                delete(app.PlotTimer);
            end
            delete(app.UIFigure)
        end
    end
end