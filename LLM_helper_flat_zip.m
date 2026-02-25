function LLM_helper_flat_zip(targetDir)
% LLM_HELPER_FLAT_ZIP Converts MLX and copies ALL non-binary files to TXT 
% in a FLAT structure, then zips them.
%
%   Usage: 
%       LLM_helper_flat_zip             % Runs on current folder (pwd)
%       LLM_helper_flat_zip('C:\Work')  % Runs on specified folder
%   
%   Output:
%       Scripts_Archive_Flat.zip (containing all files at the root level)
    
    % Default to current directory if not supplied
    if nargin < 1
        targetDir = pwd;
    end
    
    % Ensure we are on R2022a or newer
    if verLessThan('matlab', '9.12')
        error('This script requires MATLAB R2022a or later.');
    end
    
    % Standardize targetDir
    targetDir = java.io.File(targetDir).getCanonicalPath(); 
    targetDir = char(targetDir);
    
    fprintf('Scanning directory: %s\n', targetDir);
    
    % --- Define Staging Area ---
    stagingDirName = 'temp_conversion_staging';
    stagingDir = fullfile(targetDir, stagingDirName);
    
    % Ensure staging dir is clean
    if isfolder(stagingDir)
        rmdir(stagingDir, 's');
    end
    mkdir(stagingDir);
    
    cleanUpObj = onCleanup(@() cleanupStaging(stagingDir));
    
    % --- 1. Generate Master File List ---
    fprintf('Generating master file list...\n');
    allPaths = {};
    listSource = 'Unknown';
    
    % Attempt 1: MATLAB currentProject()
    try
        proj = currentProject();
        if startsWith(proj.RootFolder, targetDir, 'IgnoreCase', ispc) || startsWith(targetDir, proj.RootFolder, 'IgnoreCase', ispc)
            for k = 1:length(proj.Files)
                allPaths{end+1} = char(proj.Files(k).Path); %#ok<AGROW>
            end
            listSource = 'MATLAB currentProject()';
        end
    catch
        % Fail silently, move to Attempt 2
    end
    
    % Attempt 2: Git ls-files
    if isempty(allPaths)
        gitCmd = sprintf('cd "%s" && git ls-files', targetDir);
        [gitStatus, cmdout] = system(gitCmd);
        if gitStatus == 0 && ~isempty(cmdout)
            lines = strsplit(strtrim(cmdout), {'\r\n', '\n'});
            for k = 1:length(lines)
                if ~isempty(lines{k})
                    allPaths{end+1} = fullfile(targetDir, strrep(lines{k}, '/', filesep)); %#ok<AGROW>
                end
            end
            listSource = 'git ls-files';
        end
    end

    % Attempt 3: Fallback (Standard MATLAB dir)
    if isempty(allPaths)
        allFiles = dir(fullfile(targetDir, '**', '*.*'));
        for k = 1:length(allFiles)
            allPaths{end+1} = fullfile(allFiles(k).folder, allFiles(k).name); %#ok<AGROW>
        end
        listSource = 'MATLAB dir fallback';
    end

    % --- 2. Filter Master List and Write to TXT ---
    listFileName = fullfile(stagingDir, 'Project_Files_List.txt');
    filteredPaths = {};
    fid = fopen(listFileName, 'w');
    
    % Cross-platform `.git` folder string for matching
    gitDirPattern = [filesep, '.git', filesep]; 
    
    for k = 1:length(allPaths)
        pth = allPaths{k};
        
        % Rule 1: Must be a file (removes directories)
        if ~isfile(pth), continue; end
        
        % Rule 2: Exclude contents of `.git` folder (but keep .gitignore etc.)
        if contains(pth, gitDirPattern), continue; end
        
        % Rule 3: Exclude staging dir
        if contains(pth, stagingDir), continue; end
        
        filteredPaths{end+1} = pth; %#ok<AGROW>
        
        % Write clean relative path to the list file
        relPath = strrep(pth, [targetDir filesep], '');
        fprintf(fid, '%s\n', relPath);
    end
    fclose(fid);
    fprintf('  -> List generated using %s (%d files).\n', listSource, length(filteredPaths));

    % --- 3. Process Files (Flatten, Convert, Filter Binaries) ---
    fprintf('Processing files...\n');
    logData = {}; % Columns: {OriginalName, Location, NewFlatName, Type}
    
    for i = 1:length(filteredPaths)
        srcPath = char(filteredPaths{i});
        [srcFolder, name, ext] = fileparts(srcPath);
        srcFileName = [name, ext];
        
        % Construct flat base name (e.g., script.m -> script_m)
        if isempty(name)
            flatBase = strrep(ext, '.', '_'); % e.g. .gitignore -> _gitignore
        elseif isempty(ext)
            flatBase = name;
        else
            flatBase = [name, '_', ext(2:end)];
        end
        
        destName = getUniqueName(stagingDir, flatBase, '.txt');
        destPath = fullfile(stagingDir, destName);
        
        % Determine processing type
        if strcmpi(ext, '.mlx')
            % Export MLX to M, then rename to TXT
            tempMName = [name, '_temp_convert.m'];
            tempMPath = fullfile(stagingDir, tempMName);
            try
                export(srcPath, tempMPath);
                movefile(tempMPath, destPath);
                logData(end+1, :) = {srcFileName, srcFolder, destName, 'Converted .mlx -> .txt'}; %#ok<AGROW>
            catch ME
                fprintf('Error converting %s: %s\n', srcFileName, ME.message);
                if isfile(tempMPath), delete(tempMPath); end
            end
            
        elseif isTextFile(srcPath)
            % Normal Text/Code file -> Copy and rename to TXT
            copyfile(srcPath, destPath);
            typeStr = sprintf('Text File (%s) -> .txt', ext);
            if isempty(ext), typeStr = 'Text File -> .txt'; end
            logData(end+1, :) = {srcFileName, srcFolder, destName, typeStr}; %#ok<AGROW>
            
        else
            % Binary file -> Skip completely from zip
            % (It still remains documented in Project_Files_List.txt)
        end
    end

    % --- 4. Create CSV Log ---
    if ~isempty(logData)
        csvName = fullfile(targetDir, 'Script_Conversion_Log.csv');
        T = cell2table(logData, 'VariableNames', {'OriginalName', 'OriginalLocation', 'NewFlatName', 'Type'});
        writetable(T, csvName);
        copyfile(csvName, fullfile(stagingDir, 'Script_Conversion_Log.csv'));
    end
    
    % --- 5. Create Zip File ---
    zipName = fullfile(targetDir, 'Scripts_Archive_Flat.zip');
    fprintf('Creating Flat Zip archive...\n');
    
    zip(zipName, stagingDir);
    fprintf('Zip archive created: %s\n', zipName);
    fprintf('Operation complete.\n');
end

% --- Helper Functions ---
function uniqueName = getUniqueName(folder, baseName, ext)
    % Checks if file exists. If so, appends _1, _2, etc.
    candidate = [baseName, ext];
    counter = 1;
    
    while isfile(fullfile(folder, candidate))
        candidate = sprintf('%s_%d%s', baseName, counter, ext);
        counter = counter + 1;
    end
    uniqueName = candidate;
end

function isText = isTextFile(filePath)
    % Reads first 1024 bytes. If it contains null-bytes (0x00), it is likely binary.
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

function cleanupStaging(stagingDir)
    if isfolder(stagingDir)
        try
            rmdir(stagingDir, 's');
        catch
            warning('Could not fully delete staging dir: %s', stagingDir);
        end
    end
end