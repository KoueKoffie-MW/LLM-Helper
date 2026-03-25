function sl_data_dictionary_file_trace_extension(h)
    dictStruct = extractSLDDContents(Simulink.data.dictionary.open(h.MainArtifact.Address));
    h.MainArtifact.setCustomProperty("Symbols", jsonencode(dictStruct));
end

function dictStruct = extractSLDDContents(dictObj)
    dDataSect = getSection(dictObj, 'Design Data');
    entries = dDataSect.find;
    dictStruct = struct();
    
    for i = 1:numel(entries)
        entryName = entries(i).Name;
        entryValue = entries(i).getValue;
        if isa(entryValue, 'Simulink.Signal')
            dictStruct.Signals.(entryName) = entryValue.DataType;
        elseif isa(entryValue, 'Simulink.Bus')
            dictStruct.Buses.(entryName) = parseBus(entryValue, dDataSect);
        else
            if isfield(entryValue,"DataType")
                dictStruct.Others.(entryName) = entryValue.DataType;
            else
                dictStruct.Others.(entryName) = entryValue.BaseType;
            end
        end
    end
end

function busStruct = parseBus(busObj, dDataSect)
    busStruct = struct();
    busStruct.Description = busObj.Description;
    busStruct.DataScope = busObj.DataScope;
    busStruct.HeaderFile = busObj.HeaderFile;
    busStruct.Elements = [];

    elements = busObj.Elements;
    for i = 1:numel(elements)
        elem = elements(i);
        elemStruct = struct();
        elemStruct.Name = elem.Name;
        elemStruct.DataType = elem.DataType;
        elemStruct.Description = elem.Description;

        if ischar(elem.DataType) && ~isempty(regexp(elem.DataType, '^Bus:', 'once'))
            busName = strrep(elem.DataType, 'Bus:', '');
            dictEntries = dDataSect.find;
            idx = find(strcmp({dictEntries.Name}, busName), 1);
            if ~isempty(idx)
                nestedBusObj = busEntry.Value;
                elemStruct.NestedBus = parseBus(nestedBusObj, dDataSect);
            else
                elemStruct.NestedBus = [];
            end
        else
            elemStruct.NestedBus = [];
        end

        busStruct.Elements = [busStruct.Elements; elemStruct];
    end
end