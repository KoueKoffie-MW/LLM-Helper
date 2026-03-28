function generate_LLM_context(targetDir, varargin)
% GENERATE_LLM_CONTEXT Orchestrates multiple context-gathering scripts 
% into a single JSON file optimized for NotebookLM and REST APIs.
%
%   Usage: 
%       generate_LLM_context             % Runs on current folder (pwd)
%       generate_LLM_context('C:\Work')  % Runs on specified folder
%       generate_LLM_context(dir, 'MaxImageDepth', 2) % Limit screenshot depth
%   
%   Output:
%       [ProjectName].zip containing .json.txt fragments and images.

    % 1. Parse Inputs
    p = inputParser;
    addRequired(p, 'targetDir', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MaxImageDepth', Inf, @isnumeric);
    
    if nargin < 1
        targetDir = pwd;
    end
    parse(p, targetDir, varargin{:});
    targetDir = p.Results.targetDir;
    maxDepth = p.Results.MaxImageDepth;

    % Ensure we are on R2022a or newer
    if verLessThan('matlab', '9.12')
        error('This script requires MATLAB R2022a or later.');
    end
    
    % Standardize targetDir
    targetDir = java.io.File(targetDir).getCanonicalPath(); 
    targetDir = char(targetDir);
    
    fprintf('Generating NotebookLM Context for directory: %s\n', targetDir);
    
    % Final Data Structure
    ContextData = struct();
    ContextData.ProjectArchitecture = struct();
    ContextData.MasksAndCallbacks = [];
    ContextData.SourceCode = [];
    
    % =====================================================================
    % 1. Parse Project Architecture
    % =====================================================================
    fprintf('\n--- Step 1: Parsing Project Architecture ---\n');
    projectObj = [];
    prjFiles = dir(fullfile(targetDir, '*.prj'));
    
    if ~isempty(prjFiles)
        prjFilePath = fullfile(prjFiles(1).folder, prjFiles(1).name);
        [~, prjBaseName, ~] = fileparts(prjFiles(1).name);
        fprintf('Found project file: %s. Attempting to open...\n', prjFiles(1).name);
        try
            projectObj = openProject(prjFilePath);
            fprintf('Project opened successfully.\n');
        catch ex
            fprintf('Warning: Could not open project. Reason: %s\n', ex.message);
        end
        
        if ~isempty(projectObj)
            % Generate Architecture JSON
            try
                fprintf('Running MLProjectParser...\n');
                parser = MLProjectParser.ParseProject("prjObj", projectObj, "showAllFiles", true);
                if ~isempty(parser.rootNode) && isprop(parser.rootNode, 'children')
                    ContextData.ProjectArchitecture = parser.rootNode.children;
                end
                fprintf('Architecture parsed successfully.\n');
            catch ex
                fprintf('Warning: Could not parse architecture with MLProjectParser. Reason: %s\n', ex.message);
            end
            
            % =====================================================================
            % 1.5 Execute Simulation & Capture Images
            % =====================================================================
            fprintf('\n--- Step 1.5: Executing Simulations & Capturing Images ---\n');
            try
                ranSomething = false;
                
                % 1. Try to find and run shortcuts
                if isprop(projectObj, 'Shortcuts')
                    shortcuts = projectObj.Shortcuts;
                    for idx = 1:length(shortcuts)
                        sName = lower(shortcuts(idx).Name);
                        sGroup = '';
                        if isprop(shortcuts(idx), 'Group')
                            sGroup = lower(char(shortcuts(idx).Group));
                        end
                        if contains(sName, 'run') || contains(sName, 'sim') || contains(sName, 'main') || ...
                           contains(sGroup, 'run') || contains(sGroup, 'sim')
                            
                            sFile = shortcuts(idx).File;
                            fprintf('Executing project shortcut: %s\n', sFile);
                            [~,~,ext] = fileparts(sFile);
                            if strcmpi(ext, '.m') || strcmpi(ext, '.mlx')
                                run(sFile);
                                ranSomething = true;
                            elseif strcmpi(ext, '.slx') || strcmpi(ext, '.mdl')
                                open_system(sFile);
                                sim(sFile);
                                ranSomething = true;
                            end
                        end
                    end
                end
                
                % 2. Fallback: Check root for run/sim/main scripts
                if ~ranSomething
                    rootFiles = dir(fullfile(targetDir, '*.m'));
                    for idx = 1:length(rootFiles)
                        fName = lower(rootFiles(idx).name);
                        if startsWith(fName, 'main') || startsWith(fName, 'run') || startsWith(fName, 'sim')
                            fprintf('Executing root script: %s\n', rootFiles(idx).name);
                            run(fullfile(rootFiles(idx).folder, rootFiles(idx).name));
                            ranSomething = true;
                            break;
                        end
                    end
                end
                
                % Wait for UI to settle
                pause(2);
                
                imagesDir = fullfile(targetDir, 'NotebookLM_Images');
                if ~exist(imagesDir, 'dir')
                    mkdir(imagesDir);
                end
                
                % 3. Capture open figures
                figs = findall(0, 'Type', 'figure');
                for f = 1:length(figs)
                    figName = get(figs(f), 'Name');
                    if isempty(figName)
                        figName = sprintf('Figure_%d', f);
                    end
                    figName = regexprep(figName, '[\\/:*?"<>|]', '_'); % Clean filename
                    figPath = fullfile(imagesDir, [figName '.png']);
                    try
                        % exportapp is needed for UI components
                        exportapp(figs(f), figPath);
                    catch
                        try
                            warning('off', 'MATLAB:exportgraphics:UIComponentsNotIncluded');
                            exportgraphics(figs(f), figPath, 'Resolution', 150);
                        catch
                            saveas(figs(f), figPath);
                        end
                    end
                end
                fprintf('Captured %d figures.\n', length(figs));
                
                % 4. Capture all Simulink models deeply (excluding libraries)
                if maxDepth >= 0
                    fprintf('\n--- Step 1.6: Capturing Simulink Screenshots (MaxDepth: %g) ---\n', maxDepth);
                    capturedRefs = containers.Map('KeyType', 'char', 'ValueType', 'logical');
                    try
                        allSlx = dir(fullfile(targetDir, '**', '*.slx'));
                    for m = 1:length(allSlx)
                        [~, mdl, ~] = fileparts(allSlx(m).name);
                        % Skip known library files
                        if endsWith(lower(mdl), '_lib') || strcmpi(mdl, 'simulink')
                            continue;
                        end
                        
                        try
                            load_system(fullfile(allSlx(m).folder, allSlx(m).name));
                            if ~strcmpi(get_param(mdl, 'BlockDiagramType'), 'model')
                                close_system(mdl, 0);
                                continue; 
                            end
                            
                            % Find all subsystems with depth limit
                            findArgs = {'MatchFilter', @Simulink.match.allVariants, ...
                                        'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'SubSystem'};
                            if ~isinf(maxDepth) && maxDepth > 0
                                findArgs = [findArgs, {'SearchDepth', maxDepth}];
                            end
                            
                            subsystems = find_system(mdl, findArgs{:});
                            
                            if maxDepth == 0
                                sysToPrint = {mdl}; % Only top level
                            else
                                sysToPrint = [{mdl}; subsystems];
                            end
                            
                            capturedCount = 0;
                            for s = 1:length(sysToPrint)
                                sysName = sysToPrint{s};
                                
                                % Deduplication based on ReferenceBlock
                                try
                                    refBlock = get_param(sysName, 'ReferenceBlock');
                                catch
                                    refBlock = '';
                                end
                                
                                if ~isempty(refBlock)
                                    if isKey(capturedRefs, refBlock)
                                        % Already captured this library link
                                        continue;
                                    else
                                        capturedRefs(refBlock) = true;
                                    end
                                end
                                
                                cleanName = regexprep(sysName, '[\\/:*?"<>|]', '_');
                                mdlPath = fullfile(imagesDir, [cleanName '_Screenshot.png']);
                                try
                                    % Use print to capture
                                    print(['-s' sysName], '-dpng', '-r150', mdlPath);
                                    capturedCount = capturedCount + 1;
                                    drawnow; pause(0.01); % Yield UI thread
                                catch
                                    % Silently skip unprintable systems
                                end
                            end
                            if capturedCount > 0
                                fprintf('Captured %d model/subsystem screenshots for %s.\n', capturedCount, mdl);
                            end
                            close_system(mdl, 0);
                        catch
                            % Ignore load errors
                        end
                        end
                    catch ex
                        fprintf('Warning: Failed during model image capture: %s\n', ex.message);
                    end
                else
                    fprintf('\n--- Step 1.6: Skipping Simulink Screenshots (MaxDepth < 0) ---\n');
                end
                
            catch ex
                fprintf('Warning: Failed during simulation or image capture: %s\n', ex.message);
            end
            
        end % Closes if ~isempty(projectObj)
    else
        fprintf('No .prj file found in the root directory. Skipping Architecture Parsing.\n');
        prjBaseName = 'NotebookLM_Context';
    end

    % =====================================================================
    % 2. Extract Masks and Callbacks
    % =====================================================================
    fprintf('\n--- Step 2: Extracting Masks and Callbacks ---\n');
    try
        % find_mask_and_callback_code scans recursively if given a directory
        resultsTable = find_mask_and_callback_code(targetDir);
        
        if ~isempty(resultsTable)
            maskArray = struct('ModelName', {}, 'BlockPath', {}, 'CodeType', {}, 'CodeContent', {});
            for r = 1:height(resultsTable)
                maskArray(r).ModelName = resultsTable.ModelName{r};
                maskArray(r).BlockPath = resultsTable.BlockPath{r};
                maskArray(r).CodeType = resultsTable.CodeType{r};
                
                % Convert string to array of lines to avoid \n in JSON
                codeStr = resultsTable.CodeContent{r};
                codeLines = splitlines(string(codeStr));
                maskArray(r).CodeContent = cellstr(codeLines);
            end
            ContextData.MasksAndCallbacks = maskArray;
            fprintf('Successfully extracted %d mask/callback blocks.\n', height(resultsTable));
        else
            fprintf('No mask or callback code found.\n');
        end
    catch ex
        fprintf('Warning: Failed to extract masks and callbacks. Reason: %s\n', ex.message);
    end

    % =====================================================================
    % 3. Extract Source Code
    % =====================================================================
    fprintf('\n--- Step 3: Extracting Source Code ---\n');
    
    % We use logic similar to LLM_helper_flat_zip.m
    allFiles = generate_master_file_list(targetDir);
    sourceCodeArray = struct('Path', {}, 'Content', {});
    
    tempMName = fullfile(targetDir, 'temp_convert_MLX.m');
    cleanUpTemp = onCleanup(@() cleanupTemp(tempMName));
    
    validFilesCount = 0;
    
    % Parse .gitattributes for binary patterns
    gitAttrExts = {};
    gitAttrPath = fullfile(targetDir, '.gitattributes');
    if isfile(gitAttrPath)
        try
            attrLines = readlines(gitAttrPath);
            for k=1:length(attrLines)
                lineStr = strtrim(char(attrLines(k)));
                if isempty(lineStr) || startsWith(lineStr, '#')
                    continue;
                end
                if contains(lineStr, 'binary') || contains(lineStr, '-text') || contains(lineStr, 'text=-')
                    tokens = split(lineStr);
                    if ~isempty(tokens)
                        pat = strtrim(tokens{1});
                        if startsWith(pat, '*.')
                            gitAttrExts{end+1} = lower(pat(2:end)); %#ok<AGROW>
                        end
                    end
                end
            end
        catch
        end
    end
    cadExts = {'.stl', '.step', '.stp', '.obj', '.crg'};
    
    for i = 1:length(allFiles)
        srcPath = char(allFiles{i});
        [~, name, ext] = fileparts(srcPath);
        relPath = strrep(srcPath, [targetDir filesep], '');
        
        contentLines = {};
        
        if strcmpi(ext, '.txt') && contains(name, prjBaseName)
            continue; % Don't process our own output
        end
        if strcmpi(ext, '.json') && contains(name, prjBaseName)
            continue; % Don't process our own output
        end
        if strcmpi(ext, '.zip') && contains(name, prjBaseName)
            continue;
        end
        
        isExcludedCAD = ismember(lower(ext), cadExts);
        isBinaryAttr = ismember(lower(ext), gitAttrExts);
        
        if isExcludedCAD || isBinaryAttr
            contentLines = {['<Content excluded: Binary or CAD file (' ext ')>']};
        elseif strcmpi(ext, '.mlx')
            % Export MLX to temporary M file, then read
            try
                export(srcPath, tempMName);
                if isfile(tempMName)
                    contentLines = cellstr(readlines(tempMName));
                    delete(tempMName);
                end
            catch ME
                fprintf('  Error converting %s: %s\n', relPath, ME.message);
            end
            
        elseif ismember(lower(ext), {'.xlsx', '.xls'})
            % Handle Spreadsheets - Read all sheets
            try
                sNames = sheetnames(srcPath);
                allSheetLines = {};
                for sIdx = 1:length(sNames)
                    sName = sNames{sIdx};
                    T = readtable(srcPath, 'Sheet', sName, 'VariableNamingRule', 'preserve');
                    
                    if ~isempty(T)
                        allSheetLines{end+1} = sprintf('--- Sheet: %s ---', sName); %#ok<AGROW>
                        % Add Headers
                        allSheetLines{end+1} = strjoin(T.Properties.VariableNames, ','); %#ok<AGROW>
                        % Add Rows
                        for r = 1:height(T)
                            rowStr = cell(1, width(T));
                            for c = 1:width(T)
                                val = T{r, c};
                                if iscell(val), val = val{1}; end
                                if ismissing(val)
                                    rowStr{c} = '';
                                elseif isnumeric(val)
                                    rowStr{c} = num2str(val);
                                elseif isdatetime(val) || isduration(val) || isa(val, 'calendarDuration')
                                    rowStr{c} = char(val);
                                else
                                    rowStr{c} = char(string(val));
                                end
                            end
                            allSheetLines{end+1} = strjoin(rowStr, ','); %#ok<AGROW>
                        end
                        allSheetLines{end+1} = ''; %#ok<AGROW> % Space between sheets
                    end
                end
                contentLines = allSheetLines;
            catch ME
                fprintf('  Error reading spreadsheet %s: %s\n', relPath, ME.message);
            end
            
        elseif isTextFile(srcPath)
            % Check file size: restrict to < 1MB to prevent JSON chunk breaking
            finfo = dir(srcPath);
            if finfo.bytes > 1024 * 1024
                fprintf('  Skipping large text chunk %s (File size: %.2f MB)\n', relPath, finfo.bytes / 1e6);
                continue;
            end
            
            % Normal Text/Code file -> Read directly
            try
                contentLines = cellstr(readlines(srcPath));
            catch
                % Failed to read, likely binary masquerading as text, skip
            end
        end
        
        if ~isempty(contentLines)
            validFilesCount = validFilesCount + 1;
            sourceCodeArray(validFilesCount).Path = relPath;
            sourceCodeArray(validFilesCount).Content = contentLines;
        end
    end
    
    ContextData.SourceCode = sourceCodeArray;
    fprintf('Successfully processed %d source code and text files.\n', validFilesCount);

    % =====================================================================
    % 4. Generate JSON and Zip Structure
    % =====================================================================
    fprintf('\n--- Step 4: Finalizing Output ---\n');
    zipFileName  = fullfile(targetDir, sprintf('%s.zip', prjBaseName));
    
    fprintf('Encoding and chunking JSON (Aiming for ~2MB parts)...\n');
    
    partNum = 1;
    targetMax = 2 * 1024 * 1024; % 2MB string length
    generatedJsonFiles = {};
    
    currentPart = struct();
    if isfield(ContextData, 'ProjectArchitecture')
        currentPart.ProjectArchitecture = ContextData.ProjectArchitecture;
    end
    currentPart.MasksAndCallbacks = [];
    currentPart.SourceCode = [];
    currentSize = length(jsonencode(currentPart));
    
    itemsMC = {};
    if isfield(ContextData, 'MasksAndCallbacks') && ~isempty(ContextData.MasksAndCallbacks)
        itemsMC = num2cell(ContextData.MasksAndCallbacks);
    end
    
    itemsSC = {};
    if isfield(ContextData, 'SourceCode') && ~isempty(ContextData.SourceCode)
        itemsSC = num2cell(ContextData.SourceCode);
    end
    
    allValues = [itemsMC(:)', itemsSC(:)'];
    allLabels = [repmat({'MasksAndCallbacks'}, 1, length(itemsMC)), repmat({'SourceCode'}, 1, length(itemsSC))];
    
    for k = 1:length(allValues)
        fld = allLabels{k};
        val = allValues{k};
        
        valSize = length(jsonencode(val)) + 2; % Approx added size (+ commas)
        
        if currentSize + valSize > targetMax && (length(currentPart.MasksAndCallbacks) > 0 || length(currentPart.SourceCode) > 0)
            % Save current part
            partName = fullfile(targetDir, sprintf('%s_Part%d.json.txt', prjBaseName, partNum));
            fid = fopen(partName, 'w', 'n', 'UTF-8');
            fwrite(fid, jsonencode(currentPart, "PrettyPrint", true), 'char');
            fclose(fid);
            generatedJsonFiles{end+1} = partName; %#ok<AGROW>
            fprintf('Wrote %s\n', partName);
            
            partNum = partNum + 1;
            currentPart = struct('MasksAndCallbacks', [], 'SourceCode', []);
            currentSize = 0;
        end
        
        if strcmp(fld, 'MasksAndCallbacks')
            currentPart.MasksAndCallbacks = [currentPart.MasksAndCallbacks, val];
        else
            currentPart.SourceCode = [currentPart.SourceCode, val];
        end
        currentSize = currentSize + valSize;
    end
    
    % Save any remaining data
    if length(currentPart.MasksAndCallbacks) > 0 || length(currentPart.SourceCode) > 0 || isfield(currentPart, 'ProjectArchitecture')
        partName = fullfile(targetDir, sprintf('%s_Part%d.json.txt', prjBaseName, partNum));
        fid = fopen(partName, 'w', 'n', 'UTF-8');
        fwrite(fid, jsonencode(currentPart, "PrettyPrint", true), 'char');
        fclose(fid);
        generatedJsonFiles{end+1} = partName; %#ok<AGROW>
        fprintf('Wrote %s\n', partName);
    end
    
    fprintf('Creating Zip archive: %s\n', zipFileName);
    imagesDir = fullfile(targetDir, 'NotebookLM_Images');
    filesToZip = generatedJsonFiles;
    if exist(imagesDir, 'dir')
        filesToZip{end+1} = imagesDir;
    end
    
    % Include all .md files
    mdFiles = dir(fullfile(targetDir, '**', '*.md'));
    for k = 1:length(mdFiles)
        filesToZip{end+1} = fullfile(mdFiles(k).folder, mdFiles(k).name); %#ok<AGROW>
    end

    % Consolidate HTML files into a single master PDF using modular helper
    pdfDocPath = consolidate_html_docs(targetDir, [prjBaseName '_Documentation.pdf']);
    if ~isempty(pdfDocPath)
        filesToZip{end+1} = pdfDocPath;
    end
    
    zip(zipFileName, filesToZip);
    
    % Clean up loose JSON parts and the temporary PDF
    for k = 1:length(generatedJsonFiles)
        delete(generatedJsonFiles{k});
    end
    if isfile(pdfDocPath)
        delete(pdfDocPath);
    end
    
    % Clean up Images Directory
    if exist(imagesDir, 'dir')
        rmdir(imagesDir, 's');
    end
    
    % Close project if we opened it programmatically
    if ~isempty(projectObj)
        try
            closeProject(projectObj);
            fprintf('Closed project gracefully.\n');
        catch
        end
    end
    
    fprintf('\nDone! Found architecture tree, %d callback blocks, and %d source files.\n', ...
            length(ContextData.MasksAndCallbacks), length(ContextData.SourceCode));
end

% =========================================================================
% Helper Functions
% =========================================================================

function allPaths = generate_master_file_list(targetDir)
    % Uses fallback logic to generate a clean list of files excluding .git
    allPaths = {};
    gitDirPattern = [filesep, '.git', filesep]; 
    
    allFiles = dir(fullfile(targetDir, '**', '*.*'));
    for k = 1:length(allFiles)
        pth = fullfile(allFiles(k).folder, allFiles(k).name);
        
        if ~isfile(pth), continue; end
        if contains(pth, gitDirPattern), continue; end
        if contains(pth, 'temp_conversion_staging'), continue; end
        if contains(pth, 'NotebookLM_Context'), continue; end
        
        allPaths{end+1} = pth; %#ok<AGROW>
    end
end

function isText = isTextFile(filePath)
    % Reads first 1024 bytes. If it contains null-bytes (0x00), it's likely binary.
    fid = fopen(filePath, 'r');
    if fid == -1
        isText = false;
        return;
    end
    
    data = fread(fid, 1024, '*uint8');
    fclose(fid);
    
    if isempty(data)
        isText = true; % Empty files are considered valid text
    else
        isText = ~any(data == 0); 
    end
end

function cleanupTemp(tempFile)
    if isfile(tempFile)
        try
            delete(tempFile);
        catch
        end
    end
end
