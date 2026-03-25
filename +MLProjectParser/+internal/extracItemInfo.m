% Function to extract needed information given the item object from ML
% project
%
% Copyright 1984-2025 The MathWorks, Inc

function [artifact,name,uuid,icon,path,type,superclasstype,label] = extracItemInfo(itemInfo,g,as,iconTypeMap,rootFolder,iconPathRoot)
    
    % Compute labels
    if isempty(itemInfo.Labels)
        label = "";
    else
        label = unique(arrayfun(@(x) x.CategoryName+"."+x.Name, itemInfo.Labels));
    end

    % Compute item name and relpath
    item = extractAfter(itemInfo.Path,rootFolder+"\");
    strSplitted = strsplit(item,"\");
    name = strSplitted{end};
    path = char(extractBefore(item,name));

    % Compute type,superclasstype and icon
    artifact = g.getArtifactByUuid(as.findArtifact(itemInfo.Path));
    if isempty(artifact)
        uuid = string.empty;
        if ~contains(strSplitted{end},".")
            type = "folder";
            uuid = string.empty;
        elseif contains(item,".xml")
            warning off
            XmlInfoStruct = MLProjectParser.internal.xml2struct(item);
            if isfield(XmlInfoStruct,"HarnessInformation")
                type = "harness_info_file";
                uuid = string.empty;
            elseif isfield(XmlInfoStruct,"MF0")
                type = "zc_profile";
                uuid = string.empty;
            end
            warning on
        else
            type = "doc";
            uuid = string.empty;
        end
    else
        uuid = artifact.Guid;
        type = MLProjectParser.internal.AMLUtilities.sanitizeType(artifact);
    end
    icon = MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap(type).icon);
    superclasstype = iconTypeMap(type).superclass; 
end