# 🚀 MATLAB LLM Context Generator (LLM-Helper)

This repository provides automated context generation for MATLAB and Simulink projects, completely optimized for Large Language Models (LLMs) like **Google NotebookLM** 1\.

## 🛠️ The Core Tool: generate\_LLM\_context.m

A unified pipeline that parses your entire project and outputs an LLM-ingestible bundle 1\.

### ✨ Key Features

* 🏷️ **Project-Aware Naming**: Output files organically inherit the .prj name (e.g., MyProject\_Part1.json.txt) 1\.  
* 🧩 **Smart Chunking**: Automatically splits context into **2MB .json.txt parts** to satisfy NotebookLM's ingestion limits while maintaining JSON structural validity 1\.  
* 📸 **Deep Image Extraction with Limits**:  
* **Screenshot Depth Control**: Use MaxImageDepth to limit how many levels of subsystems are captured 1\.  
* **Library Deduplication**: Uses ReferenceBlock tracking to only capture unique library instances once, vastly reducing the image footprint 1\.  
* 🧠 **Intelligent Content Filtering**:  
* **Git-Integrated Exclusions**: Parses .gitattributes to skip binary files 1\.  
* **CAD Filtering**: Automatically excludes content from .stl, .step, .stp, and .crg files while keeping their metadata 1\.  
* **Size Safety**: Skips individual text files larger than 1MB to prevent JSON bloat 1\.  
* 📄 **Consolidated PDF Documentation**: Automatically identifies all .html files in the project and merges them into a single, high-fidelity **ProjectName\_Documentation.pdf** using a massive **A2 Portrait layout** (420mm x 594mm) 1, 2\.  
* 📊 **Excel Spreadsheet Inclusion**: Automatically reads all worksheets from .xlsx and .xls files, converting them into a text-based format to preserve tabular "source of truth" data 1\.  
* 📎 **Native Office Document Support**: Automatically identifies and bundles original Microsoft Office files (.docx, .pptx, .xlsx, etc.) in the final ZIP archive to ensure binary context is preserved 1\.  
* 💨 **Zero-Artifact In-Memory Strategy**: Documentation and data are processed **100% in memory** using absolute file:/// resource resolution. This prevents repository bloat, eliminates temporary \-pass1.html files, and ensures source HTML files remain untouched and pristine 1, 2\.  
* 📚 **Full Documentation Bundling**: Automatically includes all .md files from the project in the final archive 1\.  
* 🧹 **Workspace Hygiene**: Automatically cleans up all temporary JSON fragments, image folders, and temporary PDFs after zipping. Leaves no .mat or .xlsx residue behind 1\.

## 🗂️ Comprehensive Toolset & Scripts

Beyond the main generator, the LLM-Helper repository includes an exhaustive suite of helper scripts to process diverse MATLAB/Simulink artifacts:

### 📦 Archiving and Conversion Tools

* 🗜️ **LLM\_helper\_flat\_zip.m**: Converts .mlx (Live Scripts) and copies ALL non-binary files to .txt format in a **FLAT** directory structure, then packages them into Scripts\_Archive\_Flat.zip 3, 4\.  
* 📂 **LLM\_helper\_mfiles\_convert\_and\_zip.m**: Converts .mlx files to .txt and copies native .m files to .txt, while **preserving the original folder structure** inside a staging area 2, 4\.  
* 📑 **consolidate\_html\_docs.m**: The modular helper that reads HTML files, standardizes them in memory without altering the source files, and exports them to a unified PDF 2, 5\.  
* 🏗️ **Create\_JSON\_OF\_Project.m**: Extracts the project tree and exports it directly to a ProjectStructure.json.txt file 3\.

### 🔍 Simulink & Architecture Extraction (+MLProjectParser & \+alm)

The repository features an advanced parsing backend to dig deep into model architectures and dictionaries:

* 🕵️‍♂️ **find\_mask\_and\_callback\_code.m**: Scans Simulink models (.slx, .mdl) or entire directories to recursively extract mask initialization code and block callbacks (e.g., PreSaveFcn, InitFcn, StopFcn) 6, 7\.  
* 🌳 **Project Tree Generation (ProjectTree.m, TreeNode.m, TreeUtilities.m)**: A custom class framework that maps MATLAB project artifacts (Code, Requirements, Design, Interface, Testing, and Safety/Security artifacts) into a hierarchical tree with mapped icons and superclasses 8-13.  
* 🗺️ **Architecture Parsers (parseArchXML.m, parseProfileXML.m)**: Parses System Composer architecture files and profile XMLs to extract Views, Sequence Diagrams, Stereotypes, and Properties 14, 15\.  
* 🔠 **Data Dictionary Parsers (getSLDDHierarchy.m, sl\_data\_dictionary\_file\_trace\_extension.m)**: Safely opens and extracts the contents of Simulink Data Dictionaries (.sldd), identifying Signals, Buses, and nested Bus elements 14, 16\.  
* ⚙️ **xml2struct.m**: A robust utility to convert raw XML strings or Java XML objects into highly readable MATLAB structures 15, 17\.

## 🏗️ Understanding the JSON Data Model

The generated .json.txt files are structured to provide a comprehensive and hierarchical view of the project, specifically optimized for LLM reasoning 18:

* 📐 **ProjectArchitecture**:  
* **Logic**: Uses the MLProjectParser (from the legacy Create\_JSON\_OF\_Project.m) to generate a full hierarchical tree of the MATLAB Project 18\.  
* **Content**: Includes file dependencies, labels, and the project's folder structure. This provides the LLM with a high-level topographical map of the codebase 18\.  
* 🎭 **MasksAndCallbacks**:  
* **Logic**: Scrapes MATLAB code directly from Simulink block masks and library callbacks recursively 18\.  
* **Content**: Contains code blocks associated with specific model paths, allowing the LLM to understand block logic that isn't stored in external .m files 18\.  
* 💻 **SourceCode**:  
* **Logic**: A consolidated collection of all project-related source files 18\.  
* **Content**:  
* **MATLAB Files (.m, .mlx)**: Live Scripts are automatically exported to plain-text .m format to ensure the LLM can read the underlying code 18\.  
* **Spreadsheets (.xlsx, .xls)**: Multi-sheet parsing converts tabular data into CSV-formatted text chunks 18\.  
* **Documentation (.md)**: Included as raw markdown 18\.  
* **Binary/CAD**: Only metadata and file paths are included; binary content is excluded to prevent JSON corruption 18\.

## ⚙️ Requirements

* 🖥️ **MATLAB R2022a or newer** 19\.  
* 🧱 **Simulink** (for model screenshot and callback extraction features) 19\.  
* 📑 **MATLAB Report Generator** (for HTML-to-PDF consolidation) 19\.

## ❓ Why .json.txt?

NotebookLM and many other "Text-Only" ingestors often reject native .json files. Appending .txt allows for native upload while preserving the internal JSON structure for the LLM to parse logically 19\.  
