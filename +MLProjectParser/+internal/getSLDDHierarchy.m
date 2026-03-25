% Function to parse render a full hierarchy of a sldd file
%
% Copyright 1984-2025 The MathWorks, Inc


function getSLDDHierarchy(parentnode,ddEntrystruct,iconTypeMap,iconPathRoot,fullpath,relpath,label,prj)
    sig = ddEntrystruct.Signals;
    bus = ddEntrystruct.Buses;
    for name = fieldnames(sig)'
        type = "sl_data_dictionary_signal";
        node = addSigAndBus(parentnode,name{1}+" <"+sig.(name{1})+">",fullpath,relpath,type,iconTypeMap(type).superclass,label,prj,MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap(type).icon));
    end
    
    for name = fieldnames(bus)'
        type = "sl_data_dictionary_bus";
        node = addSigAndBus(parentnode,name{1},fullpath,relpath,type,iconTypeMap(type).superclass,label,prj,MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap(type).icon));
        arrayfun(@(x) MLProjectParser.internal.TreeUtilities.addChild(node,text=x.Name+ " <"+x.DataType+">",fullpath=fullpath,relpath=relpath,type="sl_data_dictionary_buselem",...
                              superclassType=iconTypeMap("sl_data_dictionary_buselem").superclass,label=label,project=prj.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap("sl_data_dictionary_buselem").icon)),bus.(name{1}).Elements);
    end
end

function out = addSigAndBus(parentnode,text,fullpath,relpath,type,superclassType,label,prj,icon)
    out = MLProjectParser.internal.TreeUtilities.addChild(parentnode,text=text,fullpath=fullpath,relpath=relpath,type=type,...
                                                          superclassType=superclassType,label=label,project=prj.RootFolder,icon=icon);
end