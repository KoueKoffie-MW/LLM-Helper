% Function to parse a profile file by parsing the related XML to
% extract information
%
% Copyright 1984-2025 The MathWorks, Inc


function profInfo = parseProfileXML(parentnode,pathTofile,iconTypeMap,iconPathRoot,fullpath,relpath,label,prj)
    warning off
    profInfo = MLProjectParser.internal.TreeNode('Text','Root');
    ProXmlStruct = MLProjectParser.internal.xml2struct(pathTofile);
    for stereo = ProXmlStruct.MF0.systemcomposeru_dotu_profileu_dotu_Profile.prototypes
        node = MLProjectParser.internal.TreeUtilities.addChild(parentnode,text=string(stereo{1}.pu_Name.Text),fullpath=fullpath,relpath=relpath,type="zc_stereo",...
                             superclassType=iconTypeMap("zc_stereo").superclass,label=label,project=prj.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap("zc_stereo").icon));
        if isfield(stereo{1}.propertySet,"properties")
            if iscell(stereo{1}.propertySet.properties)
                arrayfun(@(x)  MLProjectParser.internal.TreeUtilities.addChild(node,text=string(x{1}.pu_Name.Text),fullpath=fullpath,relpath=relpath,type="zc_property",...
                              superclassType=iconTypeMap("zc_property").superclass,label=label,project=prj.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap("zc_property").icon)),stereo{1}.propertySet.properties);
            else
                MLProjectParser.internal.TreeUtilities.addChild(node,text=string(stereo{1}.propertySet.properties.pu_Name.Text),fullpath=fullpath,relpath=relpath,type="zc_property",...
                              superclassType=iconTypeMap("zc_property").superclass,label=label,project=prj.RootFolder,icon=MLProjectParser.internal.AMLUtilities.sanitizeIconPath(iconPathRoot,iconTypeMap("zc_property").icon));            
            end
        end
    end
    warning on
end