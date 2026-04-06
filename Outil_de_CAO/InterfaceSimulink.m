classdef InterfaceSimulink < matlab.apps.AppBase
    
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        
        % Onglets
        TabGroup                    matlab.ui.container.TabGroup
        TabAccueil                  matlab.ui.container.Tab
        TabCalibration              matlab.ui.container.Tab
        TabParametres               matlab.ui.container.Tab
        
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
    end
    
    properties (Access = private)
        PlotTimer                   
        LiveLine                    
        LiveLinePosition            
        TimeOffset = 0;             
        TareValue = 0;              
        
        % Variables pour la sequence de calibration
        CalibDataMasses = [];
        CalibDataTensions = [];
        DerniereTensionLue = 0;
        
        % Séquence des masses demandées
        MassesCibles = [0, 1, 3, 5, 10, 20, 40, 50, 60, 80, 100];
        IndexCalibration = 1;
        EnCalibration = false;
    end
    
    methods (Access = private)
        
        % Envoi des parametres vers Simulink
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
                
                % --- CORRECTION ICI : 'gain_cou' au lieu de 'gain_cou_' ---
                assignin('base', 'gain_cou', app.GainCouEditField.Value);
                assignin('base', 'offset_cou', app.OffsetCouEditField.Value);
                assignin('base', 'num_cou', str2num(app.NumCouEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_cou', str2num(app.DenCouEditField.Value)); %#ok<ST2NM>
                
                assignin('base', 'gain_com', app.GainPWMEditField.Value);
                assignin('base', 'offset_com', app.OffsetPWMEditField.Value);
                assignin('base', 'num_com', str2num(app.NumPWMEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_com', str2num(app.DenPWMEditField.Value)); %#ok<ST2NM>
                
                status = get_param('Simulation_balance_poids_variable_realtime2024','SimulationStatus');
                if strcmp(status, 'running')
                    set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'update');
                end
            catch ME
                disp(['Erreur param : ', ME.message]);
            end
        end
        
        % Mise a jour des graphiques
        function updatePlot(app)
            status = get_param('Simulation_balance_poids_variable_realtime2024','SimulationStatus');
            
            if strcmp(status, 'running')
                try
                    t_simulink = get_param('Simulation_balance_poids_variable_realtime2024', 'SimulationTime');
                    t_continu = app.TimeOffset + t_simulink;
                    
                    if t_simulink >= 0.15
                        % Masse
                        rto_masse = get_param('Simulation_balance_poids_variable_realtime2024/ScopeSortie','RuntimeObject');
                        if ~isempty(rto_masse)
                            val_masse = double(rto_masse.InputPort(1).Data) - app.TareValue;
                            app.LiveLine.XData = [app.LiveLine.XData, t_continu];
                            app.LiveLine.YData = [app.LiveLine.YData, val_masse];
                            app.MassemesuregEditField.Value = val_masse;
                            
                            if t_continu > app.UIAxes.XLim(2)
                                app.UIAxes.XLim = [0, t_continu + 2];
                            end
                        end
                        
                        % Position
                        try
                            rto_pos = get_param('Simulation_balance_poids_variable_realtime2024/ScopePosition','RuntimeObject');
                            if ~isempty(rto_pos)
                                val_pos = double(rto_pos.InputPort(1).Data);
                                app.LiveLinePosition.XData = [app.LiveLinePosition.XData, t_continu];
                                app.LiveLinePosition.YData = [app.LiveLinePosition.YData, val_pos];
                                
                                if t_continu > app.UIAxesPosition.XLim(2)
                                    app.UIAxesPosition.XLim = [0, t_continu + 2];
                                end
                            end
                        catch
                        end
                        
                        % Tension pour calibration
                        try
                            rto_tension = get_param('Simulation_balance_poids_variable_realtime2024/ScopeTension','RuntimeObject');
                            if ~isempty(rto_tension)
                                app.DerniereTensionLue = double(rto_tension.InputPort(1).Data);
                            end
                        catch
                        end
                        
                        drawnow limitrate; 
                    end
                catch
                end
            elseif strcmp(status, 'stopped')
                if isvalid(app.PlotTimer) && strcmp(app.PlotTimer.Running, 'on')
                    stop(app.PlotTimer);
                end
            end
        end
        
        function TareButtonPushed(app, ~)
            valeur_actuelle = app.MassemesuregEditField.Value;
            app.TareValue = app.TareValue + valeur_actuelle;
            app.LiveLine.YData = app.LiveLine.YData - valeur_actuelle;
            app.MassemesuregEditField.Value = 0;
        end
        
        function ArrtersimulationButtonPushed(app, ~)
            set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'stop');
            if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                stop(app.PlotTimer);
            end
        end
        
        function EntreMassegEditFieldValueChanged(app, ~)
            nouvelle_masse = app.EntreMassegEditField.Value;
            set_param('Simulation_balance_poids_variable_realtime2024/Masse (g)', 'value', num2str(nouvelle_masse));
        end
        
        function RafrachirButtonPushed(app, ~)
            try
                t_actuel = get_param('Simulation_balance_poids_variable_realtime2024', 'SimulationTime');
                app.TimeOffset = app.TimeOffset + t_actuel;
                
                set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'stop');
                
                % --- CORRECTION ICI : Pause pour laisser Simulink s'arrêter ---
                pause(0.2);
                
                nouvelle_masse = app.EntreMassegEditField.Value;
                set_param('Simulation_balance_poids_variable_realtime2024/Masse (g)', 'Value', num2str(nouvelle_masse));
                
                evalin('base', 'Initialisation_simulation'); 
                GainValueChanged(app, []);
                
                set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'start');
                
                if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                    if strcmp(app.PlotTimer.Running, 'off')
                        start(app.PlotTimer);
                    end
                end
            catch ME
                disp(['Erreur rafraîchissement : ', ME.message]);
            end
        end
        
        function DmarrersimulationButtonPushed(app, ~)
            try
                valeur_masse = num2str(app.EntreMassegEditField.Value);
                set_param('Simulation_balance_poids_variable_realtime2024/Masse (g)', 'Value', valeur_masse);
                evalin('base', 'Initialisation_simulation'); 
                GainValueChanged(app, []);
            catch
            end
            
            app.TimeOffset = 0;
            app.LiveLine.XData = [];
            app.LiveLine.YData = [];
            app.UIAxes.XLim = [0 5]; 
            app.LiveLinePosition.XData = [];
            app.LiveLinePosition.YData = [];
            app.UIAxesPosition.XLim = [0 5]; 
            
            set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'start');
            
            if isempty(app.PlotTimer) || ~isvalid(app.PlotTimer)
                app.PlotTimer = timer('ExecutionMode', 'fixedRate', ...
                                      'Period', 0.1, ...
                                      'TimerFcn', @(~,~)updatePlot(app));
            end
            
            if strcmp(app.PlotTimer.Running, 'off')
                start(app.PlotTimer);
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
        % SEQUENCE DE CALIBRATION
        % =========================================================
        
        % Demarrage de la sequence
        function DemarrerCalibPushed(app, ~)
            % Petite sécurité : on s'assure que la simulation tourne !
            status = get_param('Simulation_balance_poids_variable_realtime2024','SimulationStatus');
            if ~strcmp(status, 'running')
                uialert(app.UIFigure, 'Veuillez démarrer la simulation dans l''onglet Accueil avant de calibrer.', 'Simulation à l''arrêt');
                return;
            end
            app.CalibDataMasses = [];
            app.CalibDataTensions = [];
            app.IndexCalibration = 1;
            app.EnCalibration = true;
            
            % Reset affichage
            app.CalibrationTable.Data = table([], [], 'VariableNames', {'Masse (g)', 'Tension brute lue'});
            app.EquationLabel.Text = 'Équation : (En attente)';
            
            % Demande la premiere masse ET force Simulink à l'utiliser
            masse_req = app.MassesCibles(app.IndexCalibration);
            set_param('Simulation_balance_poids_variable_realtime2024/Masse (g)', 'Value', num2str(masse_req));
            app.EntreMassegEditField.Value = masse_req; % Synchronise l'onglet accueil
            
            app.InstructionCalibLabel.Text = sprintf('Masse de %d g injectée. Attendez la stabilisation puis Enregistrez.', masse_req);
            app.InstructionCalibLabel.FontColor = [0 0 0]; % Noir
        end
        
        % Enregistrement d'un point
        function AcquerirPointPushed(app, ~)
            if ~app.EnCalibration
                uialert(app.UIFigure, 'Veuillez cliquer sur "Démarrer Calibration" en premier.', 'Action requise');
                return;
            end
            
            % Sauvegarde le point
            masse_actuelle = app.MassesCibles(app.IndexCalibration);
            app.CalibDataMasses = [app.CalibDataMasses; masse_actuelle];
            app.CalibDataTensions = [app.CalibDataTensions; app.DerniereTensionLue];
            
            % Met a jour la table
            app.CalibrationTable.Data = table(app.CalibDataMasses, app.CalibDataTensions, ...
                'VariableNames', {'Masse (g)', 'Tension brute lue'});
            
            % Avance dans la liste
            app.IndexCalibration = app.IndexCalibration + 1;
            
            % Verifie si c'est fini
            if app.IndexCalibration > length(app.MassesCibles)
                app.EnCalibration = false;
                app.InstructionCalibLabel.Text = 'Calibration terminée ! Calcul en cours...';
                app.InstructionCalibLabel.FontColor = [0 0.5 0]; % Vert
                
                % Lance le calcul automatiquement
                CalculerCalibPushed(app, []);
            else
                % --- CORRECTION ICI : 'masse_suivante' utilisée partout ---
                % Demande la masse suivante ET l'envoie à Simulink
                masse_suivante = app.MassesCibles(app.IndexCalibration);
                set_param('Simulation_balance_poids_variable_realtime2024/Masse (g)', 'Value', num2str(masse_suivante));
                app.EntreMassegEditField.Value = masse_suivante;
                
                app.InstructionCalibLabel.Text = sprintf('Masse de %d g injectée. Attendez la stabilisation puis Enregistrez.', masse_suivante);
            end
        end
        
        % Calcul mathematique
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
            
            % Polyfit
            calib_coeffs = polyfit(app.CalibDataTensions, app.CalibDataMasses, degre);
            
            % Affichage de l'equation
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
            
            % Envoi vers Simulink
            assignin('base', 'calib_coeffs', calib_coeffs);
            
            status = get_param('Simulation_balance_poids_variable_realtime2024','SimulationStatus');
            if strcmp(status, 'running')
                set_param('Simulation_balance_poids_variable_realtime2024', 'SimulationCommand', 'update');
            end
            
            uialert(app.UIFigure, 'La calibration est terminée et a été envoyée à Simulink.', 'Succès');
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
            app.EntreMassegEditField.ValueChangedFcn = createCallbackFcn(app, @EntreMassegEditFieldValueChanged, true);
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
            
            app.TareButton = uibutton(app.TabAccueil, 'push');
            app.TareButton.ButtonPushedFcn = createCallbackFcn(app, @TareButtonPushed, true);
            app.TareButton.Position = [X_mid 280 200 40];
            app.TareButton.Text = 'Tare (0)';
            
            app.RafrachirButton = uibutton(app.TabAccueil, 'push');
            app.RafrachirButton.ButtonPushedFcn = createCallbackFcn(app, @RafrachirButtonPushed, true);
            app.RafrachirButton.Position = [X_mid 210 200 40];
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
            app.InstructionCalibLabel.Position = [280 750 600 40];
            app.InstructionCalibLabel.FontSize = 18;
            app.InstructionCalibLabel.FontWeight = 'bold';
            app.InstructionCalibLabel.Text = 'Cliquez sur Démarrer pour lancer la séquence.';
            
            app.CalibrationTable = uitable(app.TabCalibration);
            app.CalibrationTable.Position = [50 300 400 400];
            app.CalibrationTable.ColumnName = {'Masse (g)', 'Tension brute lue'};
            
            app.AcquerirPointButton = uibutton(app.TabCalibration, 'push');
            app.AcquerirPointButton.Position = [500 650 250 50];
            app.AcquerirPointButton.Text = '2. Enregistrer la mesure';
            app.AcquerirPointButton.BackgroundColor = [0.6 0.8 1.0];
            app.AcquerirPointButton.ButtonPushedFcn = createCallbackFcn(app, @AcquerirPointPushed, true);
            
            app.DegrePolyLabel = uilabel(app.TabCalibration);
            app.DegrePolyLabel.Position = [500 580 200 22];
            app.DegrePolyLabel.Text = 'Degré du polynôme (ex: 1 = Droite) :';
            
            app.DegrePolySpinner = uispinner(app.TabCalibration);
            app.DegrePolySpinner.Position = [500 550 100 30];
            app.DegrePolySpinner.Value = 1;
            app.DegrePolySpinner.Limits = [1 5];
            
            app.CalculerCalibButton = uibutton(app.TabCalibration, 'push');
            app.CalculerCalibButton.Position = [500 480 250 50];
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