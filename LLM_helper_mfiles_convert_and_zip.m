function LLM_helper_mfiles_convert_and_zip(targetDir)
% CONVERT_AND_ZIP Converts MLX files to M files, logs them, and zips the result.
%
%   Usage: 
%       convert_and_zip             % Runs on current folder (pwd)
%       convert_and_zip('C:\Work')  % Runs on specified folder
%   
%   Workflow:
%   1. Creates a temporary staging folder.
%   2. Copies all native .m files to staging and renames them to .txt.
%   3. Converts all .mlx files to .m, then moves/renames them to .txt in staging.
%   4. Zips the staging folder content.
%   5. Deletes the staging folder (Clean Up).
%
%   This prevents "repo explosion" and ensures all archived files are .txt.

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
    % We create a temporary folder inside targetDir to hold files before zipping
    stagingDirName = 'temp_conversion_staging';
    stagingDir = fullfile(targetDir, stagingDirName);
    
    % Ensure staging dir is clean
    if isfolder(stagingDir)
        rmdir(stagingDir, 's');
    end
    mkdir(stagingDir);
    
    % Setup cleanup to ensure staging dir is deleted even if script errors
    cleanUpObj = onCleanup(@() cleanupStaging(stagingDir));

    % --- 1. Find Files ---
    % Find files but exclude the staging directory we just created
    nativeMFiles = dir(fullfile(targetDir, '**', '*.m'));
    mlxFiles = dir(fullfile(targetDir, '**', '*.mlx'));
    
    % Filter out any files that might be inside the staging dir (just in case)
    nativeMFiles = filterFiles(nativeMFiles, stagingDir);
    mlxFiles = filterFiles(mlxFiles, stagingDir);

    logData = {}; % Columns: {OriginalName, Location, NewName, Type}

    % --- 2. Process Native .m Files ---
    fprintf('Found %d native .m files. Copying and renaming to .txt...\n', length(nativeMFiles));
    
    for i = 1:length(nativeMFiles)
        srcPath = fullfile(nativeMFiles(i).folder, nativeMFiles(i).name);
        relPath = getRelativePath(srcPath, targetDir);
        
        % Prepare destination path with .txt extension
        [relFolder, relName, ~] = fileparts(relPath);
        destName = [relName, '.txt'];
        destPath = fullfile(stagingDir, relFolder, destName);
        
        % Create subfolder if needed
        ensureFolderExists(fileparts(destPath));
        
        copyfile(srcPath, destPath);
        
        logData(end+1, :) = {nativeMFiles(i).name, ...
                             nativeMFiles(i).folder, ...
                             destName, ...
                             'Native .m -> .txt'}; %#ok<AGROW>
    end

    % --- 3. Convert .mlx to .m and Rename to .txt ---
    fprintf('Found %d .mlx files. Converting and renaming to .txt...\n', length(mlxFiles));
    
    for i = 1:length(mlxFiles)
        srcFile = fullfile(mlxFiles(i).folder, mlxFiles(i).name);
        [~, name, ~] = fileparts(mlxFiles(i).name);
        
        % Calculate relative path to maintain structure
        srcFolderRel = getRelativePath(mlxFiles(i).folder, targetDir);
        
        % Determine destination in staging
        destFolder = fullfile(stagingDir, srcFolderRel);
        ensureFolderExists(destFolder);
        
        % Target name is .txt
        targetName = [name, '.txt'];
        targetPath = fullfile(destFolder, targetName);
        
        % Collision Check (e.g. if foo.m exists, foo.txt is already there)
        if isfile(targetPath)
            targetName = [name, '_converted.txt'];
            targetPath = fullfile(destFolder, targetName);
            warning('Collision: %s.txt exists. Saving converted MLX as %s', name, targetName);
        end
        
        % Intermediate .m file (Export needs .m extension to work correctly)
        tempMName = [name, '_temp.m'];
        tempMPath = fullfile(destFolder, tempMName);
        
        try
            % Export to .m first
            export(srcFile, tempMPath);
            
            % Rename/Move .m to .txt
            movefile(tempMPath, targetPath);
            
            logData(end+1, :) = {mlxFiles(i).name, ...
                                 mlxFiles(i).folder, ...
                                 targetName, ...
                                 'Converted .mlx -> .txt'}; %#ok<AGROW>
        catch ME
            fprintf('Error converting %s: %s\n', mlxFiles(i).name, ME.message);
            % Clean up temp file if it was created but move failed
            if isfile(tempMPath)
                delete(tempMPath);
            end
        end
    end

    % --- 4. Create CSV Log (Saved in TargetDir, not staging) ---
    if ~isempty(logData)
        csvName = fullfile(targetDir, 'Script_Conversion_Log.csv');
        T = cell2table(logData, 'VariableNames', {'OriginalName', 'Location', 'NewName', 'Type'});
        writetable(T, csvName);
        fprintf('Log saved to: %s\n', csvName);
        
        % Copy CSV to staging so it's included in the zip
        copyfile(csvName, fullfile(stagingDir, 'Script_Conversion_Log.csv'));
    end

    % --- 5. Create Zip File ---
    zipName = fullfile(targetDir, 'Scripts_Archive.zip');
    fprintf('Creating Zip archive...\n');
    
    % We zip the *contents* of stagingDir
    zip(zipName, stagingDir);
    fprintf('Zip archive created: %s\n', zipName);
    
    fprintf('Operation complete. Staging folder will be deleted.\n');
end

% --- Helper Functions ---

function filtered = filterFiles(filesStruct, excludePath)
    % Removes files that are inside the excluded path
    keep = true(size(filesStruct));
    for i = 1:length(filesStruct)
        if contains(filesStruct(i).folder, excludePath)
            keep(i) = false;
        end
    end
    filtered = filesStruct(keep);
end

function ensureFolderExists(folderPath)
    if ~isfolder(folderPath)
        mkdir(folderPath);
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

function relPath = getRelativePath(fullPath, rootDir)
    % Helper to strip the root directory from the full path
    
    % Normalize paths for robust comparison
    fullPath = strrep(fullPath, '\', '/');
    rootDir = strrep(rootDir, '\', '/');
    
    if endsWith(rootDir, '/')
        rootDir = rootDir(1:end-1);
    end
    
    if startsWith(fullPath, rootDir)
        relPath = extractAfter(fullPath, length(rootDir));
        if startsWith(relPath, '/')
            relPath = relPath(2:end);
        end
    else
        relPath = fullPath;
    end
    
    % Return to OS specific separators
    relPath = strrep(relPath, '/', filesep);
end