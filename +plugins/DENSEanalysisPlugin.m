classdef DENSEanalysisPlugin < hgsetget &  matlab.mixin.Heterogeneous
    % DENSEanalysisPlugin - Base class for all DENSeanalysis plugins
    %
    %   This is a bare-bones plugin class that provides the API for all
    %   plugins to DENSEanalysis
    %
    %   The required methods are:
    %
    %       run(self, DENSEdata)
    %
    %   This class is an abstract class and must be subclassed in order to
    %   create a custom plugin.

    % This Source Code Form is subject to the terms of the Mozilla Public
    % License, v. 2.0. If a copy of the MPL was not distributed with this
    % file, You can obtain one at http://mozilla.org/MPL/2.0/.
    %
    % Copyright (c) 2016 Jonathan Suever

    properties (SetAccess = 'protected')
        Name        % Plugin name specified in menus and elsewhere
        Description % Brief, description of the plugin
        Version     % String representing the version
        Author      % Author of the plugin
        Email       % Email of the author
        URL         % Url where the plugin was obtained from
    end

    properties (Access = 'protected')
        hfig        % Handle to the Figure window
        hlistener   % Listener for Tab events
        htabs       % List of popuptabs
    end

    properties (SetAccess = 'private')
        Config      % Configuration object
    end

    properties (Hidden)
        hwait       % Handle to the waitbartimer object
        Package     % Package in which the plugin is installed
    end

    properties (Dependent)
        PluginDir   % Directory in which all plugins are stored
        InstallDir  % Directory in which this specific plugin is stored
    end

    events
        Updated     % Event to be fired when this plugin is updated
        Status      % Messaging event carrying a status message payload
    end

    % Get/Set Methods
    methods
        function res = get.PluginDir(~)
            % First figure out where this file is located
            res = fileparts(mfilename('fullpath'));
        end

        function res = get.InstallDir(self)
            res = fileparts(which(class(self)));
        end
    end

    methods
        function self = DENSEanalysisPlugin(varargin)
            % Look to see if there is a plugin.json file
            jsonconfig = fullfile(self.InstallDir, 'plugin.json');

            if exist(jsonconfig, 'file')
                varargin = [{loadjson(jsonconfig)}, varargin];
            end

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.addParamValue('Name', '', @(x)ischar(x) && ~isempty(x));
            ip.addParamValue('Description', '', @ischar);
            ip.addParamValue('Version', '', @ischar);
            ip.addParamValue('Author', '', @ischar);
            ip.addParamValue('Email', '', @ischar);
            ip.addParamValue('URL', '', @ischar);
            ip.addParamValue('Package', '', @ischar);
            ip.parse(varargin{:})
            set(self, ip.Results);

            settingfile = fullfile(self.InstallDir, 'settings.json');
            self.Config = Configuration(settingfile);

            % Ensure that we have an updater config obj
            if ~isfield(self.Config, 'updater') || ...
                (iscell(self.Config.updater) && ...
                isempty(self.Config.updater))
                self.Config.updater = structobj();
            elseif ~isa(self.Config.updater, 'structobj')
                self.Config.updater = structobj(self.Config.updater);
            end

            % Locate the DENSEanalysis figure
            self.hfig = findall(0, ...
                'Type', 'figure', ...
                'tag', 'hfig');
        end

        function setStatus(self, message, varargin)
            % setStatus - Fires a `Status` event with the supplied string
            %
            % USAGE:
            %   obj.setStatus(message)
            %
            % INPUTS:
            %   message:    String, Status string to send out with the
            %               event

            if isempty(varargin); varargin = {'INFO'}; end
            eventData = StatusEvent('', message, varargin{:});
            self.notify('Status', eventData);
        end

        function validate(varargin)
            % validate - Checks whether the plugin can run
            %
            %   If any requirements of the plugin are not met, an error
            %   with a descriptive error message is thrown. This message
            %   can be checked with `isAvailable()`

            return;
        end

        function delete(self)
            % Disable the tab listener and delete it
            if ~isempty(self.hlistener) && isvalid(self.hlistener)
                self.hlistener.Enabled = false;
                delete(self.hlistener)
            end
        end

        function cleanup(self, varargin)
            % cleanup - Cleanup routine that is run by the plugin manager
            %
            % USAGE:
            %   self.cleanup()

            if ~isempty(self.hwait) && isvalid(self.hwait)
                delete(self.hwait)
            end
        end

        function hwait = waitbar(self, varargin)
            % waitbar - Creates a waitbartimer specific to the plugin
            %
            % USAGE:
            %   hwait = self.waitbar(...)
            %
            % INPUTS:
            %   ...:    Any parameter/value pair accepted by the
            %           waitbartimer. This includes 'String',
            %           'WindowStyle', etc.
            %
            % OUTPUTS:
            %   hwait:  Object, Waitbartimer object that can be used to
            %           start, stop, or modify the waitbartimer object

            if isempty(self.hwait) || ~isvalid(self.hwait)
                hwait = waitbartimer();
                self.hwait = hwait;
            else
                hwait = self.hwait;
            end

            set(hwait, varargin{:})
        end

        function varargout = hasUpdate(self, callback)
            % hasUpdate - Determines whether an update is available online
            %
            % USAGE:
            %   [bool, latest] = self.hasUpdate()
            %
            % OUTPUTS:
            %   bool:   Logical, Indicates whether an update is available
            %           (true) or not (false)
            %
            %   latest: Struct, Information about the latest available
            %           release.

            updater = Updater.create(self, 'Config', self.Config.updater);

            if ~exist('callback', 'var')
                callback = @(s,e)fprintf('%s\n', e.Message);
            end

            listener = addlistener(updater, 'Status', callback);
            cleanupobj = onCleanup(@()delete(listener));

            [varargout{1:max(nargout, 1)}] = updater.updateAvailable();

            self.Config.updater.hasUpdate = varargout{1};
        end

        function bool = update(self, varargin)
            % update - Performs an in-place update of the plugin
            %
            % USAGE:
            %   bool = self.update(silent)
            %
            % INPUTS:
            %   silent:     Logical, Forces the update to be performed
            %               without prompting the user.
            %
            % OUTPUTS:
            %   success:    Integer, Indicates whether the update was
            %               performed (1), whether the current version
            %               updates should be ignored (-1), or if the
            %               update failed (0).

            % Always force the update without a prompt for plugins
            updater = Updater.create(self, 'Config', self.Config.updater);

            listener = addlistener(updater, 'Status', @(s,e)notify(self, 'Status', e));
            cleanupobj = onCleanup(@()delete(listener));

            [bool, versionNumber] = updater.launch(varargin{:});

            if bool
                % Update the configuration based upon the new values

                % Make a copy of the current configuration
                oldconfig = copy(self.Config);

                % Now load in the settings that were downloaded with the
                % new version of the plugin
                load(self.Config);

                % Now update the downloaded settings.json with the old
                % values so that we don't forget the user's settings. If
                % the user wants to change this behavior (i.e. force old
                % values to be deleted) they will need to overload this
                % method.
                update(self.Config, oldconfig);

                % Keep track of the "internal" version number
                self.Config.updater.version = versionNumber;

                % Since we just updated we can indicate that we do not have
                % available updates
                self.Config.updater.hasUpdate = false;

                % Fire the update event
                notify(self, 'Updated');
            end
        end

        function success = uninstall(self, force)
            % uninstall - Uninstalls the plugin and removes configurations
            %
            % USAGE:
            %   success = self.uninstall(force)
            %
            % INPUTS:
            %   force:      Boolean, Indicates whether to confirm with the
            %               user or not whether to completely remove the
            %               plugin (default = false).
            %
            % OUTPUTS:
            %   success:    Boolean, Signals whether the uninstall was
            %               completed successfully.

            if ~exist('force', 'var')
                force = false;
            end

            success = false;

            if ~force

                message = [
                    'Are you sure that you want to completely remove ', ...
                    'the plugin "', self.Name, '" and all associated ', ...
                    'settings?'
                ];

                titlestr = 'Confirm Plugin Removal';

                selection = questdlg(message, titlestr, 'Yes', 'No', 'No');

                if strcmpi(selection, 'No')
                    return
                end
            end

            % Just blow away the install dir
            if exist(self.InstallDir, 'dir')
                success = rmdir(self.InstallDir, 's');
            end

            % Go ahead and delete myself here
            delete(self);
        end

        function h = uimenu(self, parent, callback, varargin)
            h = uimenu('Parent', parent, ...
                       'Callback', callback, ...
                       'Label', self.Name, ...
                       'Tag', class(self), varargin{:});
        end

        function [index, hpanel] = addPopup(self, name, height, hpanel)
            if ~ishghandle(self.hfig)
                hpanel = [];
                index = 0;
                return;
            end

            h = guidata(self.hfig);

            if ~exist('height', 'var')
                height = 200;
            end

            if ~exist('hpanel', 'var')
                hpanel = uipanel('Parent', self.hfig);
            end

            % Set the tag to be the class of this plugin so we can find it
            set(hpanel, 'Tag', class(self));

            h.hpopup.addTab(name, hpanel);
            index = h.hpopup.NumberOfTabs;
            h.hpopup.PanelHeights(index) = height;

            % If this plugin is active, then show them
            h.hpopup.Visible(index) = {'off'};
        end

        function [index, hpanel] = addTab(self, name, hpanel)
            % addTab - Add a sidetab for this plugin

            % Don't add a tab if there is no figure
            if ~ishghandle(self.hfig)
                hpanel = [];
                index = 0;
                return;
            end

            h = guidata(self.hfig);

            if ~exist('hpanel', 'var')
                hpanel = uipanel('Parent', self.hfig);
            end

            % Set the tag to be the class of this plugin so we can find it
            set(hpanel, 'Tag', class(self));

            h.hsidebar.addTab(name, hpanel);
            index = h.hsidebar.NumberOfTabs;

            % Make sure that when the panel is deleted we delete the tab
            L = addlistener(hpanel, 'ObjectBeingDestroyed', @(s,e)cleanup(s));
            setappdata(hpanel, 'SidebarListener', L);

            function cleanup(hpanel)
                if isvalid(h.hsidebar)
                    h.hsidebar.removeTab(h.hsidebar.find(hpanel));
                end
            end

            % Add a listener to changing of tab events
            self.hlistener = addlistener(h.hsidebar, ...
                'SwitchTab', @(s,e)changetab_(self, s, index));
        end

        function activateUI(self, hdata)
            % Hide the popups which aren't relevant here
            visible = repmat({'off'}, size(hdata.hpopup.Visible));

            % Now toggle the ones that we need for this plugin on
            inds = hdata.hpopup.find(class(self));
            visible(inds) = {'on'};

            hdata.hpopup.Visible = visible;
            hdata.hpopup.Enable(inds) = {'on'};
            hdata.hpopup.IsOpen(inds) = true;
        end

        function deactivateUI(self, hdata)
            inds = hdata.hpopup.find(class(self));
            hdata.hpopup.Visible(inds) = {'off'};
        end
    end

    methods (Sealed)
        function changetab_(self, hsidebar, index)
            if ~isequal(index, hsidebar.ActiveTab)
                % Disable event
                deactivateUI(self, guidata(self.hfig));
            else
                % Disable all controls by default
                activateUI(self, guidata(self.hfig));

                % Go through and enable and expand all of the controls

            end
        end

        function [available, msg] = isAvailable(self, data, varargin)
            % isAvailable - Indicates whether the plugin can run
            %
            %   If the plugin can run, this function will return true. If
            %   it cannot, it will return false along with a detailed
            %   message supplying as much information about why it can't
            %   run.
            %
            % USAGE:
            %   [bool, msg] = obj.isAvailable(data)
            %
            % INPUTS:
            %   data:   Data object that would be passed to `run` method
            %
            % OUTPUTS:
            %   bool:   Logical, Indicates whether the plugin can run
            %           (true) or not (false)
            %
            %   msg:    String, Message detailing why the plugin won't be
            %           able to be run

            msg = '';
            available = false;

            try
                self.validate(data, varargin{:})
                available = true;
            catch ME
                msg = ME.message;
            end
        end
    end

    % Abstract methods that must be overloaded by each plugin
    methods (Abstract)
        run(self, data, varargin);
    end
end
