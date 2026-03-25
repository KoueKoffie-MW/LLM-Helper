% Function to parse an architecture file by parsing the related XML to
% extract information about views and sd
%
% Copyright 1984-2025 The MathWorks, Inc

function [view, sd] = parseArchXML(r,iconTypeMap,fullpath,relpath,label,prj)
    warning off
    view = [];
    sd = [];
    try
        ViewXmlStruct = MLProjectParser.internal.xml2struct(r.readPartToString('/simulink/systemcomposer/archViews.xml'));
        view = computeNodesInfo(ViewXmlStruct.MF0.systemcomposeru_dotu_architectureu_dotu_modelu_dotu_viewsu_dotu_ViewCatalog.pu_Views,fullpath,relpath,label,prj,iconTypeMap,"zc_view");
    catch
    end
    
    try
        SDXmlStruct = MLProjectParser.internal.xml2struct(r.readPartToString('/simulink/sequencediagram/sdroot.xml'));
        sd = computeNodesInfo(SDXmlStruct.sequencediagrams.sequencediagramname,fullpath,relpath,label,prj,iconTypeMap,"zc_sequence");
    catch
    end
    warning on
end

function out = computeNodesInfo(nodesInfo,fullpath,relpath,label,prj,iconTypeMap,type)
    if iscell(nodesInfo)
        for i = 1:numel(nodesInfo)
            switch type
                case "zc_view"
                    text = strrep(string(nodesInfo{i}.pu_Name.Text),newline," ");
                case "zc_sequence"
                    text = strrep(string(nodesInfo{i}.Text),newline," ");
            end
            out(i).text = text;
            out(i).uuid = "";
            out(i).fullpath = fullpath;
            out(i).relpath  = relpath;
            out(i).type = type;
            out(i).superclassType = iconTypeMap(type).superclass;
            out(i).label  = label;
            out(i).project = prj;
            out(i).icon = iconTypeMap(type).icon;
        end
    else
        switch type
            case "zc_view"
                text = strrep(string(nodesInfo.pu_Name.Text),newline," ");
            case "zc_sequence"
                text = strrep(string(nodesInfo.Text),newline," ");
        end
        out.text = text;
        out.uuid = "";
        out.fullpath = fullpath;
        out.relpath  = relpath;
        out.type = type;
        out(i).superclassType = iconTypeMap(type).superclass;
        out.label  = label;
        out.project = prj;
        out.icon = iconTypeMap(type).icon;
    end
end

