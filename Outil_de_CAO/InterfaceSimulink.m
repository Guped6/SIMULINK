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
        TareButton                  matlab.ui.control.Button % <-- NOUVEAU BOUTON TARE
        UIAxes                      matlab.ui.control.UIAxes
    end

    % Propriétés privées pour gérer l'animation du graphique
    properties (Access = private)
        PlotTimer                   % Minuteur pour rafraîchir les données
        LiveLine                    % Objet graphique représentant la courbe
        TimeOffset = 0;             % Mémoire du temps pour la continuité
        TareValue = 0;              % <-- NOUVELLE MÉMOIRE POUR LA TARE
    end

    % Callbacks that handle component events
    methods (Access = private)

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
                            
                            % --- APPLICATION DE LA TARE ---
                            valeur_affichee = valeur_brute - app.TareValue;
                            
                            % Mettre à jour les données
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

        % --- NOUVELLE FONCTION : BOUTON TARE ---
        function TareButtonPushed(app, ~)
            % On lit la valeur actuellement affichée
            valeur_actuelle = app.MassemesuregEditField.Value;
            
            % On l'ajoute à la mémoire de la Tare
            app.TareValue = app.TareValue + valeur_actuelle;
            
            % On décale tout l'historique de la ligne graphique vers le bas
            % pour éviter que le graphique ne fasse un gros saut laid
            app.LiveLine.YData = app.LiveLine.YData - valeur_actuelle;
            
            % On met la case numérique à 0 immédiatement
            app.MassemesuregEditField.Value = 0;
            
            disp(['Tare effectuée. Soustraction de : ', num2str(app.TareValue), ' g']);
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
            catch
            end

            % Réinitialiser les données ET la Tare au démarrage
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
            app.UIFigure.Position = [100 100 640 480];
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

            % --- CRÉATION DU BOUTON TARE ---
            app.TareButton = uibutton(app.UIFigure, 'push');
            app.TareButton.ButtonPushedFcn = createCallbackFcn(app, @TareButtonPushed, true);
            app.TareButton.Position = [270 264 60 23]; % Placé à gauche de Rafraîchir
            app.TareButton.Text = 'Tare (0)';

            app.EntreMasseKgLabel = uilabel(app.UIFigure);
            app.EntreMasseKgLabel.HorizontalAlignment = 'right';
            app.EntreMasseKgLabel.Position = [30 305 100 22];
            app.EntreMasseKgLabel.Text = 'Entrée Masse (g) ';

            app.EntreMassegEditField = uieditfield(app.UIFigure, 'numeric');
            app.EntreMassegEditField.ValueChangedFcn = createCallbackFcn(app, @EntreMassegEditFieldValueChanged, true);
            app.EntreMassegEditField.Position = [145 305 100 22];

            app.MassemesuregEditFieldLabel = uilabel(app.UIFigure);
            app.MassemesuregEditFieldLabel.HorizontalAlignment = 'right';
            app.MassemesuregEditFieldLabel.Position = [30 265 112 22];
            app.MassemesuregEditFieldLabel.Text = 'Masse mesurée (g) ';

            app.MassemesuregEditField = uieditfield(app.UIFigure, 'numeric');
            app.MassemesuregEditField.ValueChangedFcn = createCallbackFcn(app, @MassemesuregEditFieldValueChanged, true);
            app.MassemesuregEditField.Editable = 'off';
            app.MassemesuregEditField.Position = [154 265 100 22];

            app.RafrachirButton = uibutton(app.UIFigure, 'push');
            app.RafrachirButton.ButtonPushedFcn = createCallbackFcn(app, @RafrachirButtonPushed, true);
            app.RafrachirButton.Position = [340 264 120 23];
            app.RafrachirButton.Text = 'Rafraîchir (Matrice)';

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