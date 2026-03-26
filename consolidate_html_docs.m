function pdfPath = consolidate_html_docs(targetDir, outputName)
    % CONSOLIDATE_HTML_DOCS Merges all .html documentation files in a directory into a single PDF.
    %
    %   pdfPath = consolidate_html_docs(targetDir)
    %   pdfPath = consolidate_html_docs(targetDir, outputName)
    %
    %   This function recursively scans targetDir for all .html files, 
    %   merges them into one consolidated PDF file, and preserves 
    %   embedded images. Required for easy ingestion into NotebookLM.
    %
    %   Requires: MATLAB Report Generator
    
    % Default output name if not provided
    if nargin < 2 || isempty(outputName)
        [~, pName] = fileparts(targetDir);
        if isempty(pName), pName = 'Project'; end
        outputName = [pName '_Documentation.pdf'];
    end
    
    pdfPath = fullfile(targetDir, outputName);
    
    % Find all .html files recursively
    htmlFiles = dir(fullfile(targetDir, '**', '*.html'));
    
    if isempty(htmlFiles)
        fprintf('No HTML files found in %s\n', targetDir);
        pdfPath = '';
        return;
    end
    
    fprintf('Consolidating %d HTML files into master PDF: %s...\n', length(htmlFiles), pdfPath);
    
    try
        import mlreportgen.dom.*;
        
        % Use the repo name for the PDF filename
        [~, projName] = fileparts(targetDir);
        pdfPath = fullfile(targetDir, [projName '_Documentation.pdf']);
        
        % Clean slate: Delete existing PDF to avoid "append" confusion or locks
        if isfile(pdfPath)
            try delete(pdfPath); catch; end
        end
        
        % Import DOM components to keep code clean
        import mlreportgen.dom.*;
        
        % Create the document container
        try
            d = Document(pdfPath, 'pdf');
            
            % [ROBUST A2 PORTRAIT LAYOUT FIX]
            % Accessing d.CurrentPageLayout before open(d) can return empty.
            % We create an explicit PDFPageLayout and append it to ensure A2 Portrait.
            plObj = PDFPageLayout();
            plObj.PageSize.Orientation = 'portrait';
            plObj.PageSize.Height = '594mm'; % A2 Height
            plObj.PageSize.Width = '420mm';  % A2 Width
            append(d, plObj);
            
        catch ME
            fprintf('Error: Could not initialize PDF document. %s\n', ME.message);
            rethrow(ME);
        end
        
        % [ZERO-ARTIFACT STRATEGY]
        % We process HTML entirely in memory to avoid generating *-pass1.html clutter.
        % Image resolution is handled by injecting absolute "file:///" URLs.
        for k = 1:length(htmlFiles)
            hFolder = htmlFiles(k).folder;
            hName = htmlFiles(k).name;
            hFullPath = fullfile(hFolder, hName);
            [~, baseName] = fileparts(hName);
            
            % 1. Read the HTML file content
            htmlStr = fileread(hFullPath);
            
            % 2. Tidy the HTML in-memory ("As-Is" rendering)
            % Removed scaling CSS as per user request to keep HTML "as is".
            try
                processedStr = mlreportgen.utils.html2dom.prepHTMLString(htmlStr);
            catch
                % Fallback: Use raw string if prep fails
                processedStr = htmlStr;
            end
            
            % [REMOVED ROBUST SCALING FIX]
            % Custom Scaling: width="100%" removed to preserve intrinsic image dimensions on the A3 canvas.
            
            % 3. Inject absolute file:/// URLs for resources
            % (Required because in-memory strings have no folder context)
            folderURL = strrep(hFolder, '\', '/');
            if ~startsWith(folderURL, '/')
                folderURL = ['/' folderURL];
            end
            absFolder = ['file://' folderURL '/'];
            
            % Replace relative src and href (only if they don't have a protocol or matlab scheme)
            % This resolves image paths while keeping internal and matlab links intact
            processedStr = regexprep(processedStr, 'src="(?!(http|file|data))', ['src="' absFolder]);
            processedStr = regexprep(processedStr, 'href="(?!(http|file|data|matlab|#))', ['href="' absFolder]);
            
            % 4. Append to PDF
            cleanTitle = strrep(baseName, '_', ' ');
            p = Paragraph(cleanTitle, 'Heading1');
            append(d, p);
            
            try
                h = HTML(processedStr);
                append(d, h);
            catch ME
                fprintf('Warning: Could not convert %s to DOM: %s\n', baseName, ME.message);
                append(d, Paragraph(['[Conversion Error: ' baseName ']']));
            end
            
            % Add a page break
            append(d, PageBreak());
        end
        
        % Finalize the PDF
        close(d);
        fprintf('Successfully generated consolidated documentation PDF (A3 Portrait): %s\n', pdfPath);
        
        % PROACTIVE DEEP CLEAN: Recursively remove any legacy residuals from previous versions
        % This is the final sweep to restore a pristine repository state.
        try
            trashFiles = dir(fullfile(targetDir, '**', '*-pass1*.html'));
            for j = 1:length(trashFiles)
                delete(fullfile(trashFiles(j).folder, trashFiles(j).name));
            end
            % Also clean up any lingering 'tp' files
            tpFiles = dir(fullfile(targetDir, '**', 'tp*.html'));
            for j = 1:length(tpFiles)
                delete(fullfile(tpFiles(j).folder, tpFiles(j).name));
            end
        catch
            % Ignore errors during final repo maintenance
        end
        
    catch ME
        fprintf('Error generating PDF documentation: %s\n', ME.message);
        pdfPath = '';
    end
end
