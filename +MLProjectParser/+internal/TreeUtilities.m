% Class with utilities to manage nodes in the tree. It contains method to
% create a tree for related artifacts given an artifacts and to add a node
% to the tree
%
% Copyright 1984-2025 The MathWorks, Inc


classdef TreeUtilities < handle
    methods (Access=public,Hidden,Static)
        
        % add child to a node
        function out = addChild(node,options)
            arguments
                node
                options.text = string.empty 
                options.uuid = string.empty 
                options.fullpath = string.empty 
                options.relpath = string.empty 
                options.type = string.empty
                options.superclassType = string.empty
                options.label = string.empty 
                options.project = string.empty 
                options.icon = string.empty
                options.almobject = string.empty;
                options.multiplicity = 1;
            end
            out = MLProjectParser.internal.TreeNode('Text',options.text,'NodeData',options.uuid,'fullpath',options.fullpath,'path',options.relpath,...
                                                    'type',options.type,'superclassType',options.superclassType,'label',options.label,...
                                                    'project',options.project,'Icon',options.icon,"almobject",options.almobject,"multiplicity",options.multiplicity);
            node.addchilds(out);
        end

        % create the tree of related artifacts given an artifacts
        function relsRootNode = createRelsTree(artifact,iconTypeMap,iconPathRoot)
            relsArray = MLProjectParser.internal.AMLUtilities.fetchFirstOrderRels(artifact);
            relsRootNode = MLProjectParser.internal.TreeNode('Text','Root');
            MLProjectParser.internal.TreeUtilities.addChild(relsRootNode,Text=relsArray(1).dir',icon='arrowNavigationWest',superclassType="container");
            MLProjectParser.internal.TreeUtilities.addChild(relsRootNode,Text=relsArray(2).dir,icon='arrowNavigationEast',superclassType="container");
            MLProjectParser.internal.TreeUtilities.packElem(relsArray(1).payload,relsRootNode,relsArray(1).dir,iconTypeMap,iconPathRoot)
            MLProjectParser.internal.TreeUtilities.packElem(relsArray(2).payload,relsRootNode,relsArray(2).dir,iconTypeMap,iconPathRoot)
        end
           
        % utility to pack element into a node
        function packElem(relsArray,relsRootNode,parentNodeName,iconTypeMap,iconPathRoot)           
            node = relsRootNode.findObj(struct('Text',parentNodeName));
            uniqueClassType = unique(arrayfun(@(x) iconTypeMap(x.Type).superclass,relsArray));            
            arrayfun(@(x) MLProjectParser.internal.TreeUtilities.addChild(node,text=x,superclassType="container",icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,"group")),uniqueClassType);
            for item = relsArray
                node = relsRootNode.findObj(struct('Text',iconTypeMap(item.Type).superclass));
                type = MLProjectParser.internal.AMLUtilities.sanitizeType(item);
                itemNode = relsRootNode.findObj(struct('NodeData',item.Guid));
                if isempty(itemNode)
                    MLProjectParser.internal.TreeUtilities.addChild(node,text=item.Label,uuid=item.Guid,type=type,...
                                                                    superclassType=iconTypeMap(type).superclass,relpath=item.Address,...
                                                                    icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap(type).icon));
                else
                    itemNode.multiplicity = itemNode.multiplicity+1;
                end
            end
        end

        % add a node to a tree
        function addNodeToTree(rootNode,ProjparentNode,item,g,as,iconTypeMap,prjRootFolder,prj,iconPathRoot)
            [artifact,itemName,itemuuid,itemIcon,itemRelPath,itemType,itemSuperClassType,itemLabel] = MLProjectParser.internal.extracItemInfo(item,g,as,iconTypeMap,prjRootFolder,iconPathRoot);
            if isempty(itemRelPath)
                parentNode = ProjparentNode;
            else
                candidateParentNode = rootNode.findObj(struct('fullpath',extractBefore(item.Path,"\"+itemName)));
                parentNode = candidateParentNode;
            end
            node = MLProjectParser.internal.TreeUtilities.addChild(parentNode,text=itemName,uuid=itemuuid,fullpath=item.Path,relpath=itemRelPath,type=itemType,superclassType=itemSuperClassType,label=itemLabel,project=prj.RootFolder,icon=itemIcon);
            if ~isempty(artifact)
                [~,allConnections] = MLProjectParser.internal.AMLUtilities.getHierarchyRecursively(artifact);
                if ~isempty(allConnections)
                    for i = 1:numel(allConnections)
                        startNode = allConnections(i).getLeftItem;
                        endNode   = allConnections(i).getRightItem;
                        type = MLProjectParser.internal.AMLUtilities.sanitizeType(endNode);
                        icon = MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap(type).icon);
                        parentObjNode = rootNode.findObj(struct('NodeData',startNode.Guid,'fullpath',item.Path));
                        MLProjectParser.internal.TreeUtilities.addChild(parentObjNode,text=strrep(string(endNode.Label),newline,""),uuid=endNode.Guid,fullpath=item.Path,...
                            relpath=itemRelPath,label=itemLabel,project=prj.RootFolder,type=type,superclassType=iconTypeMap(type).superclass,icon=icon);
                    end
                end
            end

            % TEMP FIX UNTIL AML includes views, sd and data dictionary
            switch itemType
                case {"zc_block_diagram","zc_file","zc_sw_arch","zc_refcomp"}
                    [viewNodes,sdNodes] = MLProjectParser.internal.parseArchXML(Simulink.loadsave.SLXPackageReader(which(item.Path)),iconTypeMap,item.Path,itemRelPath,itemLabel,prj);
                    MLProjectParser.internal.TreeUtilities.addViewAndsdToTree(node,viewNodes,sdNodes,iconTypeMap("zc_view").icon,iconTypeMap("zc_sequence").icon,iconPathRoot,prj);
                case "sl_data_dictionary_file"
                    % only check if there is a result from parsing the data
                    % dictionary and if there are fields to be analyze else
                    % skip it
                    if ~isempty(artifact.CustomData.at('Symbols'))
                        symbols = jsondecode(artifact.CustomData.at('Symbols'));
                        if ~isempty(fieldnames(symbols))
                            MLProjectParser.internal.getSLDDHierarchy(node,jsondecode(artifact.CustomData.at('Symbols')),iconTypeMap,iconPathRoot,item.Path,itemRelPath,itemLabel,prj);
                        end
                    end
                case {"mw_profile_file"}
                    MLProjectParser.internal.parseProfileXML(node,which(item.Path),iconTypeMap,iconPathRoot,item.Path,itemRelPath,itemLabel,prj);
            end
        end

        % TEMP FIX UNTIL AML includes views and sd
        function addViewAndsdToTree(node,view,sd,viewIcon,sdIcon,iconPathRoot,prj)
            viewrootnode = MLProjectParser.internal.TreeUtilities.addChild(node,text="views",type="container",project=prj.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,viewIcon));
            sdrootnode = MLProjectParser.internal.TreeUtilities.addChild(node,text="sequence",type="container",project=prj.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,sdIcon));
            if ~isempty(view)
                arrayfun(@(x) MLProjectParser.internal.TreeUtilities.addChild(viewrootnode,text=x.text,uuid=x.uuid,fullpath=x.fullpath,relpath=x.relpath,type=x.type,superclassType=x.superclassType,label=x.label,project=x.project.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,x.icon)),view);
            end

            if ~isempty(sd)
                arrayfun(@(x) MLProjectParser.internal.TreeUtilities.addChild(sdrootnode,text=x.text,uuid=x.uuid,fullpath=x.fullpath,relpath=x.relpath,type=x.type,superclassType=x.superclassType,label=x.label,project=x.project.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,x.icon)),sd);
            end
        end
    end
end

