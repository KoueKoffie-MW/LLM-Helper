% Class to parse ML project (including references) and get a model browser out of it
%
% Copyright 1984-2025 The MathWorks, Inc

classdef ParseProject < MLProjectParser.internal.ProjectTree

    properties (Access=public,Hidden)
        RunInApp
        ParentFig
        showAllFiles
        as
        g
        graphUpdated
        AllAtrifacts
    end

    properties (Access=public)
        log = struct('message',{},'type',{},'error',{},'details',{});
    end

    methods (Access=public)

        % main function
        function this = ParseProject(options)
            arguments
                options.prjObj matlab.project.Project = matlab.project.rootProject;
                options.showAllFiles {boolean} = false;
                options.forceRunPluginExt {boolean} = false;
                options.RunInApp {boolean} = false;
                options.ParentFig = string.empty;
            end
            this.iconTypeMap = MLProjectParser.internal.ProjectTree.Init();
            this.rootPrj = options.prjObj;
            this.referencePrj = [options.prjObj.ProjectReferences.Project];
            this.rootNode = MLProjectParser.internal.TreeNode('Text','Root');
            this.showAllFiles = options.showAllFiles;
            this.RunInApp = options.RunInApp;
            this.ParentFig = options.ParentFig;
            [this.as,this.g,this.graphUpdated] = MLProjectParser.internal.AMLUtilities.InstantiateArtifactServices(this.rootPrj.RootFolder,options.forceRunPluginExt);
            this.AllAtrifacts = MLProjectParser.internal.AMLUtilities.GetAllAtrifacts(this.g);
            
            allPrj = [this.rootPrj this.referencePrj];
            for i = 1:numel(allPrj)
                icon = MLProjectParser.internal.AMLUtilities.sanitizeIconPath(this.iconPathRoot,this.iconTypeMap("ref_proj").icon);
                if allPrj(i).TopLevel
                   icon = MLProjectParser.internal.AMLUtilities.sanitizeIconPath(this.iconPathRoot,this.iconTypeMap("top_proj").icon);
                end 
                node = MLProjectParser.internal.TreeUtilities.addChild(this.rootNode,text=allPrj(i).Name,superclassType="container",project=allPrj(i).RootFolder,icon=icon);
                this.RecursivelyGetArtifacts(node,allPrj(i),i,numel(allPrj));
            end
        end
    end

    methods (Access=private)

        % function to recursively get all artifacts in a ML project
        % (including references)
        function RecursivelyGetArtifacts(this,ProjparentNode,prj,idx,numOfPrj)
            if  ~this.showAllFiles
                items = MLProjectParser.internal.AMLUtilities.filterOutNonRelevantFiles(prj.Files);
            else
                items = prj.Files;
            end
            
            for i = 1:numel(items)
                item = items(i);
                this.renderProgress(this.RunInApp,this.ParentFig,"Parsing Project ("+num2str(idx)+"/"+num2str(numOfPrj)+") - Item ("+num2str(i)+"/"+num2str(numel(items))+")");
                try
                    MLProjectParser.internal.TreeUtilities.addNodeToTree(this.rootNode,ProjparentNode,item,this.g,this.as,this.iconTypeMap,prj.RootFolder,prj,this.iconPathRoot)
                    this.log(end+1) = this.packInfoForLog("Successfully Parsed",item);
                catch ME
                    this.log(end+1) = this.packInfoForLog("Cannot Parse",item,ME=ME);
                end
            end
        end
    
        % function to pack info for logging error
        function out = packInfoForLog(~,prefix,item,options)
            arguments
                ~ 
                prefix string
                item 
                options.ME = string.empty();
            end
            out.message = prefix + " <"+ item.Path +">";
            if isempty(options.ME)
                out.type = 'info';
                out.error = options.ME;
                out.details = options.ME;
            else
                out.type = 'error';
                out.error = options.ME.message;
                out.details = options.ME;
            end
        end

        % function to render progress-bar (if in app) or command window
        % printing (if not in app)
        function renderProgress(this,inApp,ParentFig,message)
            if inApp
                frameworks.internal.utils.handleProgessDlg(ParentFig,"update",message=message);
            else
                fprintf('Progress: %s\n', message);
            end
        end
    end
end