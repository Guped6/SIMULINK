classdef InterfaceSimulink < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
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
        
        % --- LES GAINS SONT MAINTENANT DES SPINNERS ---
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
    end

    % Propriétés privées pour gérer l'animation du graphique
    properties (Access = private)
        PlotTimer                   
        LiveLine                    
        TimeOffset = 0;             
        TareValue = 0;              
    end

    methods (Access = private)

        % Fonction de mise à jour des gains en direct
        function GainValueChanged(app, ~)
            try
                assignin('base', 'kp_pos', app.KpPosEditField.Value);
                assignin('base', 'ki_pos', app.KiPosEditField.Value);
                assignin('base', 'kd_pos', app.KdPosEditField.Value);
                
                assignin('base', 'kp_courant', app.KpCouEditField.Value);
                assignin('base', 'ki_courant', app.KiCouEditField.Value);
                
                status = get_param('Simulation_balanceversionajour2024_avec_statespace','SimulationStatus');
                if strcmp(status, 'running')
                    set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'update');
                end
            catch ME
                disp(['Erreur lors de la mise à jour des gains : ', ME.message]);
            end
        end

        % Fonction de mise à jour de l'oscilloscope
        function updatePlot(app)
            status = get_param('Simulation_balanceversionajour2024_avec_statespace','SimulationStatus');
            
            if strcmp(status, 'running')
                try
                    t_simulink = get_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationTime');
                    t_continu = app.TimeOffset + t_simulink;
                    
                    if t_simulink >= 0.15
                        rto = get_param('Simulation_balanceversionajour2024_avec_statespace/Scope10','RuntimeObject');
                        
                        if ~isempty(rto)
                            valeur_brute = double(rto.InputPort(1).Data);
                            valeur_affichee = valeur_brute - app.TareValue;
                            
                            app.LiveLine.XData = [app.LiveLine.XData, t_continu];
                            app.LiveLine.YData = [app.LiveLine.YData, valeur_affichee];
                            app.MassemesuregEditField.Value = valeur_affichee;
                            
                            if t_continu > app.UIAxes.XLim(2)
                                app.UIAxes.XLim = [t_continu-5, t_continu];
                            end
                            
                            drawnow limitrate; 
                        end
                    end
                catch
                end
            elseif strcmp(status, 'stopped')
                if isvalid(app.PlotTimer) && strcmp(app.PlotTimer.Running, 'on')
                    stop(app.PlotTimer);
                end
            end
        end

        % Fonction Tare
        function TareButtonPushed(app, ~)
            valeur_actuelle = app.MassemesuregEditField.Value;
            app.TareValue = app.TareValue + valeur_actuelle;
            app.LiveLine.YData = app.LiveLine.YData - valeur_actuelle;
            app.MassemesuregEditField.Value = 0;
        end

        % Bouton Arrêter 
        function ArrtersimulationButtonPushed(app, ~)
            set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'stop');
            if ~isempty(app.PlotTimer) && isvalid(app.PlotTimer)
                stop(app.PlotTimer);
            end
        end

        % Changement Entrée Masse
        function EntreMassegEditFieldValueChanged(app, ~)
            nouvelle_masse = app.EntreMassegEditField.Value;
            valeur_texte = num2str(nouvelle_masse);
            set_param('Simulation_balanceversionajour2024_avec_statespace/Masse (g)', 'value', valeur_texte);
        end

        % Bouton Rafraîchir
        function RafrachirButtonPushed(app, ~)
            try
                t_actuel = get_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationTime');
                app.TimeOffset = app.TimeOffset + t_actuel;
                
                set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'stop');
                
                nouvelle_masse = app.EntreMassegEditField.Value;
                valeur_texte = num2str(nouvelle_masse);
                set_param('Simulation_balanceversionajour2024_avec_statespace/Masse (g)', 'Value', valeur_texte);
                
                evalin('base', 'Initialisation_simulation'); 
                GainValueChanged(app, []);
                
                set_param('Simulation_balanceversionajour2024_avec_statespace', 'SimulationCommand', 'start');
                
                if strcmp(app.PlotTimer.Running, 'off')
                    start(app.PlotTimer);
                end
            catch ME
                disp(['Erreur lors du rafraîchissement : ', ME.message]);
            end
        end

        function MassemesuregEditFieldValueChanged(app, ~)
        end

        % Bouton Démarrer
        function DmarrersimulationButtonPushed(app, ~)
            try
                valeur_masse = num2str(app.EntreMassegEditField.Value);
                set_param('Simulation_balanceversionajour2024_avec_statespace/Masse (g)', 'Value', valeur_masse);
                evalin('base', 'Initialisation_simulation'); 
                GainValueChanged(app, []);
            catch
            end

            app.TimeOffset = 0;
            app.TareValue = 0; 
            app.LiveLine.XData = [];
            app.LiveLine.YData = [];
            app.UIAxes.XLim = [0 5]; 
            
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
      
        % Bouton pour effacer le graphique
        function ClearButtonPushed(app, ~)
            app.LiveLine.XData = [];
            app.LiveLine.YData = [];
            app.UIAxes.XLim = [0 5]; 
        end
    end

    % Component initialization
    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 800 480]; 
            app.UIFigure.Name = 'Interface Balance';

            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Masse mesurée (g) selon le temps (s)')
            xlabel(app.UIAxes, 'Temps (s)')
            ylabel(app.UIAxes, 'Masse mesurée (g)')
            app.UIAxes.XLimMode = 'auto';
            app.UIAxes.XTickMode = 'auto';
            app.UIAxes.XTickLabelMode = 'auto';
            app.UIAxes.YLimMode = 'auto';
            app.UIAxes.YTickMode = 'auto';
            app.UIAxes.YTickLabelMode = 'auto';
            app.UIAxes.Position = [30 33 546 222];

            grid(app.UIAxes, 'on');
            hold(app.UIAxes, 'on');
            app.LiveLine = plot(app.UIAxes, NaN, NaN, 'b-', 'LineWidth', 1.5);

            app.DmarrersimulationButton = uibutton(app.UIFigure, 'push');
            app.DmarrersimulationButton.ButtonPushedFcn = createCallbackFcn(app, @DmarrersimulationButtonPushed, true);
            app.DmarrersimulationButton.Position = [22 397 123 23];
            app.DmarrersimulationButton.Text = 'Démarrer simulation';

            app.ArrtersimulationButton = uibutton(app.UIFigure, 'push');
            app.ArrtersimulationButton.ButtonPushedFcn = createCallbackFcn(app, @ArrtersimulationButtonPushed, true);
            app.ArrtersimulationButton.Position = [22 354 123 23];
            app.ArrtersimulationButton.Text = 'Arrêter simulation';

            app.ClearButton = uibutton(app.UIFigure, 'push');
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            app.ClearButton.Position = [160 354 123 23]; 
            app.ClearButton.Text = 'Effacer graphique';

            app.TareButton = uibutton(app.UIFigure, 'push');
            app.TareButton.ButtonPushedFcn = createCallbackFcn(app, @TareButtonPushed, true);
            app.TareButton.Position = [270 264 60 23];
            app.TareButton.Text = 'Tare (0)';

            app.EntreMasseKgLabel = uilabel(app.UIFigure);
            app.EntreMasseKgLabel.HorizontalAlignment = 'right';
            app.EntreMasseKgLabel.Position = [30 305 100 22];
            app.EntreMasseKgLabel.Text = 'Entrée Masse (g) ';

            app.EntreMassegEditField = uieditfield(app.UIFigure, 'numeric');
            app.EntreMassegEditField.ValueDisplayFormat = '%.2f'; % <-- FORMAT 2 DÉCIMALES
            app.EntreMassegEditField.ValueChangedFcn = createCallbackFcn(app, @EntreMassegEditFieldValueChanged, true);
            app.EntreMassegEditField.Position = [145 305 100 22];

            app.MassemesuregEditFieldLabel = uilabel(app.UIFigure);
            app.MassemesuregEditFieldLabel.HorizontalAlignment = 'right';
            app.MassemesuregEditFieldLabel.Position = [30 265 112 22];
            app.MassemesuregEditFieldLabel.Text = 'Masse mesurée (g) ';

            app.MassemesuregEditField = uieditfield(app.UIFigure, 'numeric');
            app.MassemesuregEditField.ValueDisplayFormat = '%.2f'; % <-- FORMAT 2 DÉCIMALES
            app.MassemesuregEditField.ValueChangedFcn = createCallbackFcn(app, @MassemesuregEditFieldValueChanged, true);
            app.MassemesuregEditField.Editable = 'off';
            app.MassemesuregEditField.Position = [154 265 100 22];

            app.RafrachirButton = uibutton(app.UIFigure, 'push');
            app.RafrachirButton.ButtonPushedFcn = createCallbackFcn(app, @RafrachirButtonPushed, true);
            app.RafrachirButton.Position = [340 264 120 23];
            app.RafrachirButton.Text = 'Rafraîchir (Matrice)';

            % =========================================================
            % --- SECTION : GAINS (AVEC SPINNERS) ---
            % =========================================================
            app.TitrePositionLabel = uilabel(app.UIFigure);
            app.TitrePositionLabel.Position = [600 380 150 22];
            app.TitrePositionLabel.FontWeight = 'bold';
            app.TitrePositionLabel.Text = 'Régulateur Position';

            app.KpPosLabel = uilabel(app.UIFigure);
            app.KpPosLabel.Position = [600 350 40 22];
            app.KpPosLabel.Text = 'Kp :';
            app.KpPosEditField = uispinner(app.UIFigure); % <-- SPINNER
            app.KpPosEditField.Position = [640 350 80 22];
            app.KpPosEditField.Value = 2.325;
            app.KpPosEditField.Step = 0.1; % Taille du saut
            app.KpPosEditField.ValueDisplayFormat = '%.3f';
            app.KpPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            app.KiPosLabel = uilabel(app.UIFigure);
            app.KiPosLabel.Position = [600 320 40 22];
            app.KiPosLabel.Text = 'Ki :';
            app.KiPosEditField = uispinner(app.UIFigure);
            app.KiPosEditField.Position = [640 320 80 22];
            app.KiPosEditField.Value = -27.5;
            app.KiPosEditField.Step = 0.5;
            app.KiPosEditField.ValueDisplayFormat = '%.2f';
            app.KiPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            app.KdPosLabel = uilabel(app.UIFigure);
            app.KdPosLabel.Position = [600 290 40 22];
            app.KdPosLabel.Text = 'Kd :';
            app.KdPosEditField = uispinner(app.UIFigure);
            app.KdPosEditField.Position = [640 290 80 22];
            app.KdPosEditField.Value = -0.207;
            app.KdPosEditField.Step = 0.01;
            app.KdPosEditField.ValueDisplayFormat = '%.3f';
            app.KdPosEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            % ========================================================
            % --- SECTION : GAINS DE LA BOUCLE DE COURANT ---
            % ========================================================
            app.TitreCourantLabel = uilabel(app.UIFigure);
            app.TitreCourantLabel.Position = [600 240 150 22];
            app.TitreCourantLabel.FontWeight = 'bold';
            app.TitreCourantLabel.Text = 'Régulateur Courant';

            app.KpCouLabel = uilabel(app.UIFigure);
            app.KpCouLabel.Position = [600 210 40 22];
            app.KpCouLabel.Text = 'Kp :';
            app.KpCouEditField = uispinner(app.UIFigure);
            app.KpCouEditField.Position = [640 210 80 22];
            app.KpCouEditField.Value = -0.575;
            app.KpCouEditField.Step = 0.05;
            app.KpCouEditField.ValueDisplayFormat = '%.3f';
            app.KpCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            app.KiCouLabel = uilabel(app.UIFigure);
            app.KiCouLabel.Position = [600 180 40 22];
            app.KiCouLabel.Text = 'Ki :';
            app.KiCouEditField = uispinner(app.UIFigure);
            app.KiCouEditField.Position = [640 180 80 22];
            app.KiCouEditField.Value = -325;
            app.KiCouEditField.Step = 5;
            app.KiCouEditField.ValueDisplayFormat = '%.1f';
            app.KiCouEditField.ValueChangedFcn = createCallbackFcn(app, @GainValueChanged, true);

            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
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