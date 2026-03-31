classdef InterfaceSimulink < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        
        % --- BOUTONS ET CONTRÔLES ---
        RafrachirButton             matlab.ui.control.Button
        MassemesuregEditField       matlab.ui.control.NumericEditField
        MassemesuregEditFieldLabel  matlab.ui.control.Label
        EntreMassegEditField        matlab.ui.control.NumericEditField
        EntreMasseKgLabel           matlab.ui.control.Label
        ArrtersimulationButton      matlab.ui.control.Button
        DmarrersimulationButton     matlab.ui.control.Button
        ClearButton                 matlab.ui.control.Button
        TareButton                  matlab.ui.control.Button
        
        % --- GRAPHIQUES ---
        UIAxes                      matlab.ui.control.UIAxes % Masse
        UIAxesPosition              matlab.ui.control.UIAxes % Position
        
        % --- LE GRAND TITRE ---
        SectionParamLabel           matlab.ui.control.Label

        % --- RÉGULATEURS ---
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
        
        % --- RÉSOLUTION ---
        TitreBitsLabel              matlab.ui.control.Label
        BitsADCLabel                matlab.ui.control.Label
        BitsADCEditField            matlab.ui.control.Spinner
        BitsDACLabel                matlab.ui.control.Label
        BitsDACEditField            matlab.ui.control.Spinner

        % --- COND. POSITION ---
        TitreCondPosLabel           matlab.ui.control.Label
        GainPosLabel                matlab.ui.control.Label
        GainPosEditField            matlab.ui.control.Spinner
        OffsetPosLabel              matlab.ui.control.Label
        OffsetPosEditField          matlab.ui.control.Spinner
        NumPosLabel                 matlab.ui.control.Label
        NumPosEditField             matlab.ui.control.EditField % Texte pour array
        DenPosLabel                 matlab.ui.control.Label
        DenPosEditField             matlab.ui.control.EditField % Texte pour array

        % --- COND. COURANT ---
        TitreCondCouLabel           matlab.ui.control.Label
        GainCouLabel                matlab.ui.control.Label
        GainCouEditField            matlab.ui.control.Spinner
        OffsetCouLabel              matlab.ui.control.Label
        OffsetCouEditField          matlab.ui.control.Spinner
        NumCouLabel                 matlab.ui.control.Label
        NumCouEditField             matlab.ui.control.EditField
        DenCouLabel                 matlab.ui.control.Label
        DenCouEditField             matlab.ui.control.EditField

        % --- COND. PWM ---
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
        LiveLine                    % Courbe de masse
        LiveLinePosition            % Courbe de position
        TimeOffset = 0;             
        TareValue = 0;              
    end

    methods (Access = private)
        
        function GainValueChanged(app, ~)
            try
                % Gains Régulateurs
                assignin('base', 'kp_pos', app.KpPosEditField.Value);
                assignin('base', 'ki_pos', app.KiPosEditField.Value);
                assignin('base', 'kd_pos', app.KdPosEditField.Value);
                assignin('base', 'kp_courant', app.KpCouEditField.Value);
                assignin('base', 'ki_courant', app.KiCouEditField.Value);
                
                % Bits
                assignin('base', 'bits_adc', app.BitsADCEditField.Value);
                assignin('base', 'bits_dac', app.BitsDACEditField.Value);

                % Conditionnement Position
                assignin('base', 'gain_pos', app.GainPosEditField.Value);
                assignin('base', 'offset_pos', app.OffsetPosEditField.Value);
                assignin('base', 'num_pos', str2num(app.NumPosEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_pos', str2num(app.DenPosEditField.Value)); %#ok<ST2NM>

                % Conditionnement Courant
                assignin('base', 'gain_cou_', app.GainCouEditField.Value);
                assignin('base', 'offset_cou', app.OffsetCouEditField.Value);
                assignin('base', 'num_cou', str2num(app.NumCouEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_cou', str2num(app.DenCouEditField.Value)); %#ok<ST2NM>

                % Conditionnement PWM
                assignin('base', 'gain_com', app.GainPWMEditField.Value);
                assignin('base', 'offset_com', app.OffsetPWMEditField.Value);
                assignin('base', 'num_com', str2num(app.NumPWMEditField.Value)); %#ok<ST2NM>
                assignin('base', 'denom_com', str2num(app.DenPWMEditField.Value)); %#ok<ST2NM>
                
                status = get_param('Simulation_balanceversionajour2024_avec_statespace','SimulationStatus');
                if strcmp(status, 'running')
                    set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'update');
                end
            catch ME
                disp(['Erreur lors de la mise à jour des paramètres : ', ME.message]);
            end
        end

        function updatePlot(app)
            status = get_param('Simulation_balanceversionajour2024_avec_statespace','SimulationStatus');
            
            if strcmp(status, 'running')
                try
                    t_simulink = get_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationTime');
                    t_continu = app.TimeOffset + t_simulink;
                    
                    if t_simulink >= 0.15
                        % 1. LECTURE DE LA MASSE
                        rto_masse = get_param('Simulation_balanceversionajour2024_avec_statespace/Scope10','RuntimeObject');
                        if ~isempty(rto_masse)
                            val_masse = double(rto_masse.InputPort(1).Data) - app.TareValue;
                            app.LiveLine.XData = [app.LiveLine.XData, t_continu];
                            app.LiveLine.YData = [app.LiveLine.YData, val_masse];
                            app.MassemesuregEditField.Value = val_masse;
                            
                            if t_continu > app.UIAxes.XLim(2)
                                app.UIAxes.XLim = [0, t_continu + 2];
                            end
                        end

                        % 2. LECTURE DE LA POSITION (Assure-toi d'avoir un "ScopePosition" dans Simulink !)
                        try
                            rto_pos = get_param('Simulation_balanceversionajour2024_avec_statespace/ScopePosition','RuntimeObject');
                            if ~isempty(rto_pos)
                                val_pos = double(rto_pos.InputPort(1).Data);
                                app.LiveLinePosition.XData = [app.LiveLinePosition.XData, t_continu];
                                app.LiveLinePosition.YData = [app.LiveLinePosition.YData, val_pos];
                                
                                if t_continu > app.UIAxesPosition.XLim(2)
                                    app.UIAxesPosition.XLim = [0, t_continu + 2];
                                end
                            end
                        catch
                            % Si le ScopePosition n'existe pas encore, on ignore pour éviter un crash
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
            set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'stop');
            if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                stop(app.PlotTimer);
            end
        end

        function EntreMassegEditFieldValueChanged(app, ~)
            nouvelle_masse = app.EntreMassegEditField.Value;
            set_param('Simulation_balanceversionajour2024_avec_statespace/Masse (g)', 'value', num2str(nouvelle_masse));
        end

        function RafrachirButtonPushed(app, ~)
            try
                t_actuel = get_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationTime');
                app.TimeOffset = app.TimeOffset + t_actuel;
                
                set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'stop');
                
                nouvelle_masse = app.EntreMassegEditField.Value;
                set_param('Simulation_balanceversionajour2024_avec_statespace/Masse (g)', 'Value', num2str(nouvelle_masse));
                
                evalin('base', 'Initialisation_simulation'); 
                GainValueChanged(app, []);
                
                set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'start');
                
                if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                    if strcmp(app.PlotTimer.Running, 'off')
                        start(app.PlotTimer);
                    end
                end
            catch ME
                disp(['Erreur lors du rafraîchissement : ', ME.message]);
            end
        end

        function MassemesuregEditFieldValueChanged(app, ~)
        end

        function DmarrersimulationButtonPushed(app, ~)
            try
                valeur_masse = num2str(app.EntreMassegEditField.Value);
                set_param('Simulation_balanceversionajour2024_avec_statespace/Masse (g)', 'Value', valeur_masse);
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
            
            set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'start');
            
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
    end

    methods (Access = private)
        function createComponents(app)
            % GRANDE FENÊTRE POUR TOUT RENTRER
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1200 850]; 
            app.UIFigure.Name = 'Interface Centre de Contrôle';
            
            % =========================================================
            % --- COLONNE 1 : LES GRAPHIQUES ---
            % =========================================================
            % Graphique 1 : Masse
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Masse mesurée (g) selon le temps (s)')
            xlabel(app.UIAxes, 'Temps (s)')
            ylabel(app.UIAxes, 'Masse mesurée (g)')
            app.UIAxes.Position = [20 450 550 350];
            grid(app.UIAxes, 'on'); hold(app.UIAxes, 'on');
            app.LiveLine = plot(app.UIAxes, NaN, NaN, 'b-', 'LineWidth', 1.5);

            % Graphique 2 : Position
            app.UIAxesPosition = uiaxes(app.UIFigure);
            title(app.UIAxesPosition, 'Position de la lame (m) selon le temps (s)')
            xlabel(app.UIAxesPosition, 'Temps (s)')
            ylabel(app.UIAxesPosition, 'Position (m)')
            app.UIAxesPosition.Position = [20 50 550 350];
            grid(app.UIAxesPosition, 'on'); hold(app.UIAxesPosition, 'on');
            app.LiveLinePosition = plot(app.UIAxesPosition, NaN, NaN, 'r-', 'LineWidth', 1.5);
            
            % =========================================================
            % --- COLONNE 2 : CONTRÔLES PRINCIPAUX ---
            % =========================================================
            X_mid = 620;
            app.DmarrersimulationButton = uibutton(app.UIFigure, 'push');
            app.DmarrersimulationButton.ButtonPushedFcn = createCallbackFcn(app, @DmarrersimulationButtonPushed, true);
            app.DmarrersimulationButton.Position = [X_mid 700 150 40];
            app.DmarrersimulationButton.Text = 'Démarrer simulation';
            app.DmarrersimulationButton.BackgroundColor = [0.47 0.87 0.47]; % Vert pâle
            
            app.ArrtersimulationButton = uibutton(app.UIFigure, 'push');
            app.ArrtersimulationButton.ButtonPushedFcn = createCallbackFcn(app, @ArrtersimulationButtonPushed, true);
            app.ArrtersimulationButton.Position = [X_mid 640 150 40];
            app.ArrtersimulationButton.Text = 'Arrêter simulation';
            app.ArrtersimulationButton.BackgroundColor = [0.87 0.47 0.47]; % Rouge pâle
            
            app.ClearButton = uibutton(app.UIFigure, 'push');
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            app.ClearButton.Position = [X_mid 580 150 30]; 
            app.ClearButton.Text = 'Effacer graphiques';
            
            app.EntreMasseKgLabel = uilabel(app.UIFigure);
            app.EntreMasseKgLabel.Position = [X_mid 500 150 22];
            app.EntreMasseKgLabel.Text = 'Entrée Masse (g) :';
            
            app.EntreMassegEditField = uieditfield(app.UIFigure, 'numeric');
            app.EntreMassegEditField.ValueChangedFcn = createCallbackFcn(app, @EntreMassegEditFieldValueChanged, true);
            app.EntreMassegEditField.Position = [X_mid 475 150 30];
            
            app.MassemesuregEditFieldLabel = uilabel(app.UIFigure);
            app.MassemesuregEditFieldLabel.Position = [X_mid 420 150 22];
            app.MassemesuregEditFieldLabel.Text = 'Masse mesurée (g) :';
            
            app.MassemesuregEditField = uieditfield(app.UIFigure, 'numeric');
            app.MassemesuregEditField.Editable = 'off';
            app.MassemesuregEditField.Position = [X_mid 395 150 30];
            app.MassemesuregEditField.BackgroundColor = [0.9 0.9 0.9];
            
            app.TareButton = uibutton(app.UIFigure, 'push');
            app.TareButton.ButtonPushedFcn = createCallbackFcn(app, @TareButtonPushed, true);
            app.TareButton.Position = [X_mid 340 150 30];
            app.TareButton.Text = 'Tare (0)';
            
            app.RafrachirButton = uibutton(app.UIFigure, 'push');
            app.RafrachirButton.ButtonPushedFcn = createCallbackFcn(app, @RafrachirButtonPushed, true);
            app.RafrachirButton.Position = [X_mid 280 150 40];
            app.RafrachirButton.Text = 'Rafraîchir (Matrice)';
            app.RafrachirButton.BackgroundColor = [0.6 0.8 1.0];
            
            % =========================================================
            % --- COLONNE 3 : PARAMÈTRES AVANCÉS ---
            % =========================================================
            X_R1 = 820; % Colonne paramètres
            X_R2 = 910; % Colonne valeurs
            
            app.SectionParamLabel = uilabel(app.UIFigure);
            app.SectionParamLabel.Position = [X_R1 800 250 25];
            app.SectionParamLabel.FontWeight = 'bold';
            app.SectionParamLabel.FontSize = 16;
            app.SectionParamLabel.Text = 'Paramètres de l''architecture :';

            % --- Régulateur Position ---
            app.TitrePositionLabel = uilabel(app.UIFigure);
            app.TitrePositionLabel.Position = [X_R1 760 150 22];
            app.TitrePositionLabel.FontWeight = 'bold';
            app.TitrePositionLabel.Text = 'Régulateur Position';
            
            app.KpPosLabel = uilabel(app.UIFigure); app.KpPosLabel.Position = [X_R1 735 80 22]; app.KpPosLabel.Text = 'Kp :';
            app.KpPosEditField = uispinner(app.UIFigure); app.KpPosEditField.Position = [X_R2 735 90 22]; app.KpPosEditField.Value = 2.325; app.KpPosEditField.Step = 0.1; app.KpPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.KiPosLabel = uilabel(app.UIFigure); app.KiPosLabel.Position = [X_R1 710 80 22]; app.KiPosLabel.Text = 'Ki :';
            app.KiPosEditField = uispinner(app.UIFigure); app.KiPosEditField.Position = [X_R2 710 90 22]; app.KiPosEditField.Value = -27.5; app.KiPosEditField.Step = 0.5; app.KiPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.KdPosLabel = uilabel(app.UIFigure); app.KdPosLabel.Position = [X_R1 685 80 22]; app.KdPosLabel.Text = 'Kd :';
            app.KdPosEditField = uispinner(app.UIFigure); app.KdPosEditField.Position = [X_R2 685 90 22]; app.KdPosEditField.Value = -0.207; app.KdPosEditField.Step = 0.01; app.KdPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % --- Régulateur Courant ---
            app.TitreCourantLabel = uilabel(app.UIFigure);
            app.TitreCourantLabel.Position = [X_R1 645 150 22];
            app.TitreCourantLabel.FontWeight = 'bold';
            app.TitreCourantLabel.Text = 'Régulateur Courant';
            
            app.KpCouLabel = uilabel(app.UIFigure); app.KpCouLabel.Position = [X_R1 620 80 22]; app.KpCouLabel.Text = 'Kp :';
            app.KpCouEditField = uispinner(app.UIFigure); app.KpCouEditField.Position = [X_R2 620 90 22]; app.KpCouEditField.Value = -0.575; app.KpCouEditField.Step = 0.05; app.KpCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.KiCouLabel = uilabel(app.UIFigure); app.KiCouLabel.Position = [X_R1 595 80 22]; app.KiCouLabel.Text = 'Ki :';
            app.KiCouEditField = uispinner(app.UIFigure); app.KiCouEditField.Position = [X_R2 595 90 22]; app.KiCouEditField.Value = -325; app.KiCouEditField.Step = 5; app.KiCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            % --- Cond. Acquisition Position ---
            app.TitreCondPosLabel = uilabel(app.UIFigure);
            app.TitreCondPosLabel.Position = [X_R1 555 200 22];
            app.TitreCondPosLabel.FontWeight = 'bold';
            app.TitreCondPosLabel.Text = 'Cond. Acquisition (Position)';
            
            app.GainPosLabel = uilabel(app.UIFigure); app.GainPosLabel.Position = [X_R1 530 80 22]; app.GainPosLabel.Text = 'Gain :';
            app.GainPosEditField = uispinner(app.UIFigure); app.GainPosEditField.Position = [X_R2 530 90 22]; app.GainPosEditField.Value = 1.0; app.GainPosEditField.Step = 0.1; app.GainPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.OffsetPosLabel = uilabel(app.UIFigure); app.OffsetPosLabel.Position = [X_R1 505 80 22]; app.OffsetPosLabel.Text = 'Offset :';
            app.OffsetPosEditField = uispinner(app.UIFigure); app.OffsetPosEditField.Position = [X_R2 505 90 22]; app.OffsetPosEditField.Value = 0.0; app.OffsetPosEditField.Step = 0.1; app.OffsetPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.NumPosLabel = uilabel(app.UIFigure); app.NumPosLabel.Position = [X_R1 480 80 22]; app.NumPosLabel.Text = 'Filtre Num :';
            app.NumPosEditField = uieditfield(app.UIFigure, 'text'); app.NumPosEditField.Position = [X_R2 480 150 22]; app.NumPosEditField.Value = '[1]'; app.NumPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.DenPosLabel = uilabel(app.UIFigure); app.DenPosLabel.Position = [X_R1 455 80 22]; app.DenPosLabel.Text = 'Filtre Den :';
            app.DenPosEditField = uieditfield(app.UIFigure, 'text'); app.DenPosEditField.Position = [X_R2 455 150 22]; app.DenPosEditField.Value = '[1 0.001]'; app.DenPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            % --- Cond. Acquisition Courant ---
            app.TitreCondCouLabel = uilabel(app.UIFigure);
            app.TitreCondCouLabel.Position = [X_R1 415 200 22];
            app.TitreCondCouLabel.FontWeight = 'bold';
            app.TitreCondCouLabel.Text = 'Cond. Acquisition (Courant)';
            
            app.GainCouLabel = uilabel(app.UIFigure); app.GainCouLabel.Position = [X_R1 390 80 22]; app.GainCouLabel.Text = 'Gain :';
            app.GainCouEditField = uispinner(app.UIFigure); app.GainCouEditField.Position = [X_R2 390 90 22]; app.GainCouEditField.Value = 1.0; app.GainCouEditField.Step = 0.1; app.GainCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.OffsetCouLabel = uilabel(app.UIFigure); app.OffsetCouLabel.Position = [X_R1 365 80 22]; app.OffsetCouLabel.Text = 'Offset :';
            app.OffsetCouEditField = uispinner(app.UIFigure); app.OffsetCouEditField.Position = [X_R2 365 90 22]; app.OffsetCouEditField.Value = 0.0; app.OffsetCouEditField.Step = 0.1; app.OffsetCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.NumCouLabel = uilabel(app.UIFigure); app.NumCouLabel.Position = [X_R1 340 80 22]; app.NumCouLabel.Text = 'Filtre Num :';
            app.NumCouEditField = uieditfield(app.UIFigure, 'text'); app.NumCouEditField.Position = [X_R2 340 150 22]; app.NumCouEditField.Value = '[1]'; app.NumCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.DenCouLabel = uilabel(app.UIFigure); app.DenCouLabel.Position = [X_R1 315 80 22]; app.DenCouLabel.Text = 'Filtre Den :';
            app.DenCouEditField = uieditfield(app.UIFigure, 'text'); app.DenCouEditField.Position = [X_R2 315 150 22]; app.DenCouEditField.Value = '[1 0.001]'; app.DenCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            % --- Cond. Commande (PWM) ---
            app.TitreCondPWMLabel = uilabel(app.UIFigure);
            app.TitreCondPWMLabel.Position = [X_R1 275 200 22];
            app.TitreCondPWMLabel.FontWeight = 'bold';
            app.TitreCondPWMLabel.Text = 'Cond. Commande (PWM)';
            
            app.GainPWMLabel = uilabel(app.UIFigure); app.GainPWMLabel.Position = [X_R1 250 80 22]; app.GainPWMLabel.Text = 'Gain :';
            app.GainPWMEditField = uispinner(app.UIFigure); app.GainPWMEditField.Position = [X_R2 250 90 22]; app.GainPWMEditField.Value = 1.0; app.GainPWMEditField.Step = 0.1; app.GainPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.OffsetPWMLabel = uilabel(app.UIFigure); app.OffsetPWMLabel.Position = [X_R1 225 80 22]; app.OffsetPWMLabel.Text = 'Offset :';
            app.OffsetPWMEditField = uispinner(app.UIFigure); app.OffsetPWMEditField.Position = [X_R2 225 90 22]; app.OffsetPWMEditField.Value = 0.0; app.OffsetPWMEditField.Step = 0.1; app.OffsetPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.NumPWMLabel = uilabel(app.UIFigure); app.NumPWMLabel.Position = [X_R1 200 80 22]; app.NumPWMLabel.Text = 'Filtre Num :';
            app.NumPWMEditField = uieditfield(app.UIFigure, 'text'); app.NumPWMEditField.Position = [X_R2 200 150 22]; app.NumPWMEditField.Value = '[1]'; app.NumPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.DenPWMLabel = uilabel(app.UIFigure); app.DenPWMLabel.Position = [X_R1 175 80 22]; app.DenPWMLabel.Text = 'Filtre Den :';
            app.DenPWMEditField = uieditfield(app.UIFigure, 'text'); app.DenPWMEditField.Position = [X_R2 175 150 22]; app.DenPWMEditField.Value = '[1 0.001]'; app.DenPWMEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            % --- Résolution (ADC/DAC) ---
            app.TitreBitsLabel = uilabel(app.UIFigure);
            app.TitreBitsLabel.Position = [X_R1 135 150 22];
            app.TitreBitsLabel.FontWeight = 'bold';
            app.TitreBitsLabel.Text = 'Résolution (Bits)';
            
            app.BitsADCLabel = uilabel(app.UIFigure); app.BitsADCLabel.Position = [X_R1 110 80 22]; app.BitsADCLabel.Text = 'ADC :';
            app.BitsADCEditField = uispinner(app.UIFigure); app.BitsADCEditField.Position = [X_R2 110 90 22]; app.BitsADCEditField.Value = 12; app.BitsADCEditField.Step = 1; app.BitsADCEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);
            
            app.BitsDACLabel = uilabel(app.UIFigure); app.BitsDACLabel.Position = [X_R1 85 80 22]; app.BitsDACLabel.Text = 'DAC :';
            app.BitsDACEditField = uispinner(app.UIFigure); app.BitsDACEditField.Position = [X_R2 85 90 22]; app.BitsDACEditField.Value = 12; app.BitsDACEditField.Step = 1; app.BitsDACEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

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