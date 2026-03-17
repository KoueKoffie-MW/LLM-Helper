function resultsTable = find_mask_and_callback_code(searchPath)
    % FIND_MASK_AND_CALLBACK_CODE Scans a Simulink model or directory for mask and callback code.
    %
    % Input:
    %   searchPath - Name of the Simulink model or path to a directory
    %
    % Output:
    %   resultsTable - A MATLAB table containing the model, block path, code type, and code content.

    % If a directory is provided, recursively find all models
    if isfolder(searchPath)
        % Check for a .prj file in the provided directory
        prjFiles = dir(fullfile(searchPath, '*.prj'));
        projectObj = [];
        if ~isempty(prjFiles)
            prjFilePath = fullfile(prjFiles(1).folder, prjFiles(1).name);
            fprintf('Found project file: %s. Attempting to open project...\n', prjFiles(1).name);
            try
                % Attempting to open the project. 
                projectObj = openProject(prjFilePath);
            catch ex
                fprintf('Could not open project automatically. Reason: %s\n', ex.message);
            end
        end
        
        slxFiles = dir(fullfile(searchPath, '**', '*.slx'));
        mdlFiles = dir(fullfile(searchPath, '**', '*.mdl'));
        allModelFiles = [slxFiles; mdlFiles];
        
        allResults = cell(length(allModelFiles), 1);
        
        for k = 1:length(allModelFiles)
            [~, mdlName, ~] = fileparts(allModelFiles(k).name);
            mdlFolder = allModelFiles(k).folder;
            fprintf('Scanning model: %s...\n', mdlName);
            
            % Add the model's folder to the MATLAB path temporarily if project wasn't opened
            if isempty(projectObj)
                addpath(mdlFolder);
            end
            
            try
                allResults{k} = find_mask_and_callback_code(mdlName);
            catch ex
                fprintf('Could not process model: %s. Reason: %s\n', mdlName, ex.message);
            end
            
            % Remove the folder from the path to keep environment clean if project wasn't opened
            if isempty(projectObj)
                rmpath(mdlFolder);
            end
        end
        
        % Close the project if we opened it
        if ~isempty(projectObj)
            try
                closeProject(projectObj);
                fprintf('Closed project: %s\n', prjFiles(1).name);
            catch
                fprintf('Please close the project manually. Programmatic close failed.\n');
            end
        end
        
        resultsTable = vertcat(allResults{:});
        if ~isempty(resultsTable)
            
            % Clean up newlines to prevent rows from breaking in Excel
            resultsTable.CodeContent = regexprep(resultsTable.CodeContent, '[\r\n]+', ' ');
            
            save('Project_CodeScanResults.mat', 'resultsTable');
            writetable(resultsTable, 'Project_CodeScanResults.xlsx');
            fprintf('Finished scanning directory. Aggregate results saved to Project_CodeScanResults.mat and Project_CodeScanResults.xlsx\n');
        end
        return;
    end
    
    modelName = searchPath;

    % Ensure the model is loaded and track if we need to close it later
    wasLoaded = bdIsLoaded(modelName);
    if ~wasLoaded
        load_system(modelName);
    end

    % Find all blocks in the model
    allBlocks = find_system(modelName, 'Type', 'block');
    
    % Define the standard block callbacks to check
    callbackNames = {
        'CopyFcn', 'DeleteFcn', 'UndoDeleteFcn', ...
        'PreCopyFcn', 'PostCopyFcn', 'PreDeleteFcn', ...
        'PostDeleteFcn', 'LoadFcn', 'PreSaveFcn', ...
        'PostSaveFcn', 'InitFcn', 'StartFcn', ...
        'PauseFcn', 'ContinueFcn', 'StopFcn', ...
        'NameChangeFcn', 'ClipboardFcn', 'OpenFcn', ...
        'CloseFcn', 'ModelCloseFcn', 'MoveFcn', 'ParentCloseFcn'
    };

    % Initialize storage for findings
    foundModels = {};
    foundPaths = {};
    foundTypes = {};
    foundCode = {};

    % Iterate through each block
    for i = 1:length(allBlocks)
        block = allBlocks{i};
        
        % 1. Check for Mask Initialization Code
        try
            maskCode = get_param(block, 'MaskInitialization');
            if ~isempty(strtrim(maskCode)) && ~contains(maskCode, '.internal.')
                foundModels{end+1} = modelName; %#ok<*AGROW>
                foundPaths{end+1} = block;
                foundTypes{end+1} = 'Mask Initialization';
                foundCode{end+1} = maskCode;
            end
        catch
            % Not all blocks have mask properties; ignore errors
        end

        % 1b. Check for Mask Display (Image/Drawing) Code
        try
            maskDisplayCode = get_param(block, 'MaskDisplay');
            if ~isempty(strtrim(maskDisplayCode)) && ~contains(maskDisplayCode, '.internal.')
                foundModels{end+1} = modelName; %#ok<*AGROW>
                foundPaths{end+1} = block;
                foundTypes{end+1} = 'Mask Display';
                foundCode{end+1} = maskDisplayCode;
            end
        catch
            % Not all blocks have mask properties; ignore errors
        end

        % 2. Check for Block Callbacks
        for j = 1:length(callbackNames)
            cbName = callbackNames{j};
            try
                cbCode = get_param(block, cbName);
                if ~isempty(strtrim(cbCode)) && ~contains(cbCode, '.internal.')
                    foundModels{end+1} = modelName;
                    foundPaths{end+1} = block;
                    foundTypes{end+1} = ['Callback: ' cbName];
                    foundCode{end+1} = cbCode;
                end
            catch
                % Parameter might not exist for this block type
            end
        end
    end

    % Create results table
    if isempty(foundPaths)
        fprintf('No mask code or callbacks found in model: %s\n', modelName);
        resultsTable = table();
    else
        resultsTable = table(foundModels', foundPaths', foundTypes', foundCode', ...
            'VariableNames', {'ModelName', 'BlockPath', 'CodeType', 'CodeContent'});
        
        % Clean up newlines to prevent rows from breaking in Excel
        resultsTable.CodeContent = regexprep(resultsTable.CodeContent, '[\r\n]+', ' ');
        
        % Optionally save to a .mat file or spreadsheet
        savePathMAT = [modelName '_CodeScanResults.mat'];
        savePathExcel = [modelName '_CodeScanResults.xlsx'];
        save(savePathMAT, 'resultsTable');
        writetable(resultsTable, savePathExcel);
        fprintf('Found %d instances of code. Results saved to %s and %s\n', height(resultsTable), savePathMAT, savePathExcel);
    end

    % Close the model to free up memory, if we were the ones who loaded it
    if ~wasLoaded
        bdclose(modelName);
    end
end