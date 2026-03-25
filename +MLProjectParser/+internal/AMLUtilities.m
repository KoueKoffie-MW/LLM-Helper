% Class for artifacts lifecycle management utilities function like
% artifacts navigation, get related artifacts and traverse hierarchy
%
% Copyright 1984-2025 The MathWorks, Inc

classdef AMLUtilities < handle
   methods (Access=public,Hidden,Static)

       %% initialize artifact services
       function [as,g,isUpdateNeeded] = InstantiateArtifactServices(prjRootFolder,forceRunPluginExt)
           as = alm.internal.ArtifactService.get(prjRootFolder);
           if forceRunPluginExt
               as.scheduleAllArtifacts;
           end
           isUpdateNeeded = jsondecode(as.serviceCall("updateArtifacts", "{}")).result.GraphModified;
           g = as.getGraph();
       end

       %% get all artifacts
       function out = GetAllAtrifacts(g)
           out = g.getAllArtifacts;
       end

       %% filter out not relevant file (i.e. ".slmx" and .git files)
       function out = filterOutNonRelevantFiles(allItems)
           out = allItems(arrayfun(@(x) (~endsWith(x.Path,".slmx") && ~contains(x.Path,".git")),allItems));
       end

       %% navigate to element 
       function navigateToElement(itemsTreeObj,as,nodedata,id)
           if ~isempty(id)
                as.openArtifact(id);
           else
               MLProjectParser.internal.AMLUtilities.openItem(itemsTreeObj,nodedata)
           end
       end

       %% get hierarchy recursively given an artifact
       function [item,connections] = getHierarchyRecursively(artifact)
            import alm.gdb.tql.*;
            ef = ExpressionFactory();
            tb = TraversalBuilder;
            tb.setRootNodeExpression(ef.exprAny());
            tb.addOutgoingExpression(ef.exprAny(), ef.exprRelationshipContains(), ef.exprAny())
            tb.addOutgoingExpression(ef.exprAny(), ef.exprRelationshipRequires(), ef.exprArtifact(ExpressionConstraint('Type',{'sl_block_diagram', 'zc_block_diagram', 'sl_subsytem'})))
            r =tb.execute(artifact);
            item = r.getArtifacts;
            connections = r.getConnections;
       end

       %% get first order relationship ("REQUIRES") given an artifact
       function relsStruct = fetchFirstOrderRels(artifact)
           relsStruct(1).dir = "Incoming";
           relsStruct(1).payload = MLProjectParser.internal.AMLUtilities.getRequiresRels(artifact,"IncomingRelationships","SourceItem");
           relsStruct(2).dir = "Outgoing";
           relsStruct(2).payload = MLProjectParser.internal.AMLUtilities.getRequiresRels(artifact,"OutgoingRelationships","DestinationItem");
       end

       %% utility function to get rels of type "REQUIRES"
       function out = getRequiresRels(artifact,reslDir,targetItem)
           out = [];
           if ~isempty(artifact.(reslDir).toArray)
               if numel(artifact.(reslDir).toArray) > 1
                   allReqRels = arrayfun(@(x) {findobj(x.(targetItem).(reslDir).toArray,"Type","REQUIRES").(targetItem)},artifact.(reslDir).toArray,'UniformOutput',false);
                   out =[out;MLProjectParser.internal.AMLUtilities.packRelsIntoArray(allReqRels)];
               else
                   out =[out;findobj(artifact.(reslDir).toArray.(targetItem).(reslDir).toArray,"Type","REQUIRES").(targetItem)];
               end
           end
       end

       %% utility function to pack rels object into an array
       function out = packRelsIntoArray(relsobj)
           out = [];
           for item = relsobj
               if ~isempty(item{1})
                   out = [out arrayfun(@(x) x{1},item{1})];
               end
           end
       end

       %% utility function to compute the fully qualified path of the icon for the node
       function out = sanitizeIconPath(pathRoot,iconname)
           if isfile(pathRoot+iconname+".svg")
               %out = pathRoot+iconname+".svg";
               out = iconname;
           else
               %out = which("+MLProjectParser/+images/"+iconname+".svg");
               out = iconname+".svg";
           end
       end

       %% utility function to get project issues
       function out = getProjectIssues(as)
           as.updateArtifacts;
           out = as.serviceCall("transformToTree", jsonencode(struct("treetype", "trace-issues", "uuid", alm.internal.uuid.generateNilUuid())));
           out = jsondecode(jsondecode(out).result);
       end
        
       %% TEMP FIX utility function to sanitize type for ZC reference
       % component. If parent is a ZC_* then type is zc_component, else is
       % the value returned from the alm interface
       function out = sanitizeType(artifact)
           out = artifact.Type;
           if ~isempty(artifact.ParentArtifact)
               if ~contains(artifact.Type,"zc_") && contains(artifact.ParentArtifact.Type,"zc_")
                   out = "zc_component";
               end
           end
       end

       %% TEMP FIX utility to navigate to element not know from the ALM service artifact
       function openItem(itemsTreeObj,nodedata)
           switch nodedata.superclassType
               case 'external'
                   winopen(nodedata.fullpath)
               case 'architecture'
                   MLProjectParser.internal.AMLUtilities.openProfileViewAndSD(nodedata);
               case 'dictionary'
                   dd = Simulink.data.dictionary.open(nodedata.fullpath);
                   dd.show;
           end
       end

       %% TEMP FIX utility to open profile, views and sd
       function openProfileViewAndSD(nodedata)
           switch nodedata.type
               case {'zc_profile','zc_stereo','zc_property'}
                   systemcomposer.loadProfile(nodedata.fullpath);
                   systemcomposer.profile.editor;
               case 'zc_view'
                   zcModel = systemcomposer.loadModel(nodedata.fullpath);
                   zcModel.openViews
                   app = systemcomposer.internal.arch.load(nodedata.fullpath);
                   studioMgr = app.getArchViewsAppMgr.getStudioMgr;
                   viewToOpen = zcModel.getView(nodedata.Text);
                   studioMgr.changeRoot(viewToOpen.getImpl, systemcomposer.architecture.model.design.BaseComponent.empty);
               case 'zc_sequence'
                   zcModel = systemcomposer.loadModel(nodedata.fullpath);
                   zcModel.openViews
                   sdToOpen = zcModel.getInteraction(nodedata.Text);
                   sdToOpen.open;
           end
       end
   end
end