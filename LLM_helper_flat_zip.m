function LLM_helper_flat_zip(targetDir)
% LLM_HELPER_FLAT_ZIP Converts MLX/M to TXT and zips them into a FLAT structure.
%
%   Usage: 
%       LLM_helper_flat_zip             % Runs on current folder (pwd)
%       LLM_helper_flat_zip('C:\Work')  % Runs on specified folder
%   
%   Output:
%       Scripts_Archive.zip (containing all files at the root level)

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

    % --- 1. Find Files ---
    nativeMFiles = dir(fullfile(targetDir, '**', '*.m'));
    mlxFiles = dir(fullfile(targetDir, '**', '*.mlx'));
    
    % Filter out staging dir files
    nativeMFiles = filterFiles(nativeMFiles, stagingDir);
    mlxFiles = filterFiles(mlxFiles, stagingDir);

    logData = {}; % Columns: {OriginalName, Location, NewFlatName, Type}

    % --- 2. Process Native .m Files ---
    fprintf('Found %d native .m files. Copying to flat .txt...\n', length(nativeMFiles));
    
    for i = 1:length(nativeMFiles)
        srcPath = fullfile(nativeMFiles(i).folder, nativeMFiles(i).name);
        [~, name, ~] = fileparts(nativeMFiles(i).name);
        
        % Get unique filename for flat structure
        destName = getUniqueName(stagingDir, name, '.txt');
        destPath = fullfile(stagingDir, destName);
        
        copyfile(srcPath, destPath);
        
        logData(end+1, :) = {nativeMFiles(i).name, ...
                             nativeMFiles(i).folder, ...
                             destName, ...
                             'Native .m -> .txt'}; %#ok<AGROW>
    end

    % --- 3. Process .mlx Files ---
    fprintf('Found %d .mlx files. Converting to flat .txt...\n', length(mlxFiles));
    
    for i = 1:length(mlxFiles)
        srcFile = fullfile(mlxFiles(i).folder, mlxFiles(i).name);
        [~, name, ~] = fileparts(mlxFiles(i).name);
        
        % Get unique filename for flat structure
        destName = getUniqueName(stagingDir, name, '.txt');
        destPath = fullfile(stagingDir, destName);
        
        % Intermediate .m file needs to be unique too
        tempMName = [name, '_temp_convert.m'];
        tempMPath = fullfile(stagingDir, tempMName);
        
        try
            % Export to .m first
            export(srcFile, tempMPath);
            
            % Rename/Move .m to .txt
            movefile(tempMPath, destPath);
            
            logData(end+1, :) = {mlxFiles(i).name, ...
                                 mlxFiles(i).folder, ...
                                 destName, ...
                                 'Converted .mlx -> .txt'}; %#ok<AGROW>
        catch ME
            fprintf('Error converting %s: %s\n', mlxFiles(i).name, ME.message);
            if isfile(tempMPath), delete(tempMPath); end
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

function filtered = filterFiles(filesStruct, excludePath)
    keep = true(size(filesStruct));
    for i = 1:length(filesStruct)
        if contains(filesStruct(i).folder, excludePath)
            keep(i) = false;
        end
    end
    filtered = filesStruct(keep);
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