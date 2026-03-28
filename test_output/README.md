# MATLAB LLM Context Generator

This repository provides automated context generation for MATLAB and Simulink projects, optimized for Large Language Models (LLMs) like **Google NotebookLM**.

## The Core Tool: `generate_LLM_context.m`

A unified pipeline that parses a project and outputs an LLM-ingestible bundle.

### Key Features

*   **Project-Aware Naming**: Output files organically inherit the `.prj` name (e.g., `MyProject_Part1.json.txt`).
*   **Smart Chunking**: Automatically splits context into **2MB `.json.txt` parts** to satisfy NotebookLM's ingestion limits while maintaining JSON structural validity.
*   **Deep Image Extraction with Limits**:
    *   **Screenshot Depth Control**: Use `'MaxImageDepth'` to limit how many levels of subsystems are captured.
    *   **Library Deduplication**: Uses `ReferenceBlock` tracking to only capture unique library instances once, vastly reducing image footprint.
*   **Intelligent Content Filtering**:
    *   **Git-Integrated Exclusions**: Parses `.gitattributes` to skip binary files.
    *   **CAD Filtering**: Automatically excludes content from `.stl`, `.step`, `.stp`, and `.crg` files while keeping their metadata.
    *   **Size Safety**: Skips individual text files larger than 1MB to prevent JSON bloat.
*   **Consolidated PDF Documentation**: Automatically identifies all `.html` files in the project and merges them into a single, high-fidelity **`[ProjectName]_Documentation.pdf`** using a massive **A2 Portrait layout** (420mm x 594mm).
*   **Excel Spreadsheet Inclusion**: Automatically reads all worksheets from `.xlsx` and `.xls` files, converting them into a text-based format to preserve tabular "source of truth" data.
*   **Native Office Document Support**: Automatically identifies and bundles original Microsoft Office files (`.docx`, `.pptx`, `.xlsx`, etc.) in the final ZIP archive to ensure binary context is preserved.
*   **Zero-Artifact In-Memory Strategy**: Documentation and data are processed **100% in memory** using absolute `file:///` resource resolution. This prevents repository bloat, eliminates temporary `-pass1.html` files, and ensures source HTML files remain untouched and pristine.
*   **Full Documentation Bundling**: Automatically includes all `.md` files from the project in the final archive.
*   **Workspace Hygiene**: Automatically cleans up all temporary JSON fragments, image folders, and temporary PDFs after zipping. No `.mat` or `.xlsx` residue.

## Understanding the JSON Data Model

The generated `.json.txt` files are structured to provide a comprehensive and hierarchical view of the project, specifically optimized for LLM reasoning:

*   **`ProjectArchitecture`**: 
    *   **Logic**: Uses the `MLProjectParser` (from the legacy `Create JSON of Project.m`) to generate a full hierarchical tree of the MATLAB Project.
    *   **Content**: Includes file dependencies, labels, and the project's folder structure. This provides the LLM with a high-level topographical map of the codebase.
*   **`MasksAndCallbacks`**: 
    *   **Logic**: Scrapes MATLAB code directly from Simulink block masks and library callbacks recursively.
    *   **Content**: Contains code blocks associated with specific model paths, allowing the LLM to understand block logic that isn't stored in external `.m` files.
*   **`SourceCode`**: 
    *   **Logic**: A consolidated collection of all project-related source files.
    *   **Content**:
        *   **MATLAB Files (`.m`, `.mlx`)**: Live Scripts are automatically exported to plain-text `.m` format to ensure the LLM can read the underlying code.
        *   **Spreadsheets (`.xlsx`, `.xls`)**: Multi-sheet parsing converts tabular data into CSV-formatted text chunks.
        *   **Documentation (`.md`)**: Included as raw markdown.
        *   **Binary/CAD**: Only metadata and file paths are included; binary content is excluded to prevent JSON corruption.

### Usage

```matlab
% Basic run (Infinitely deep screenshots + PDF documentation)
generate_LLM_context('C:\Path\To\Project')

% Limited recursion (Capture Top-Level + 2 levels of subsystems)
generate_LLM_context(pwd, 'MaxImageDepth', 2)

% No screenshots (Text only)
generate_LLM_context(pwd, 'MaxImageDepth', -1)

% Root level screenshots only
generate_LLM_context(pwd, 'MaxImageDepth', 0)

%% Standalone Documentation Consolidation
% If you only need to update the documentation PDF without running the full pipeline:
consolidate_html_docs('C:\Path\To\Project')
```

### Output Structure

```
YourProject/
  ├── [ProjectName]_Part1.json.txt      # Chunked JSON (Part 1)
  ├── [ProjectName]_Part2.json.txt      # Chunked JSON (Part 2)
  ├── [ProjectName]_Documentation.pdf   # Merged HTML Documentation
  ├── [ProjectName].zip                 # Consolidated Bundle
  └── (Temporary folders are auto-cleaned)
```

## Requirements

*   MATLAB **R2022a or newer**
*   Simulink (for model screenshot features)
*   **MATLAB Report Generator** (for HTML-to-PDF consolidation)

## Why `.json.txt`?

NotebookLM and many other "Text-Only" ingestors often reject `.json` files. Appending `.txt` allows for native upload while preserving the internal JSON structure for the LLM to parse logically.