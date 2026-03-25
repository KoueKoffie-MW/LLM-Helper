% Class to instantiate properties and icon-to-type map for object of the
% project tree
%
% Copyright 1984-2025 The MathWorks, Inc


classdef ProjectTree < handle
    properties (Access=public)
       rootPrj
       referencePrj
       rootNode
       iconTypeMap
       iconPathRoot = matlabroot+"\ui\icons\16x16\";
    end

    methods (Static,Hidden)
        function map = Init()
            map = containers.Map();

            % matlab superclass
            map("m_class") = struct("superclass","matlab","icon","class","color","brown","group","Code Artifacts");
            map("m_enum") = struct("superclass","matlab","icon","enumClass","color","brown","group","Code Artifacts");
            map("m_file") = struct("superclass","matlab","icon","genericFile","color","brown","group","Code Artifacts");
            map("m_func") = struct("superclass","matlab","icon","functionText","color","brown","group","Code Artifacts");
            map("m_method") = struct("superclass","matlab","icon","method_class","color","brown","group","Code Artifacts");
            map("m_property") = struct("superclass","matlab","icon","property_class","color","brown","group","Code Artifacts");

            % req superclass
            map("mwreq_file") = struct("superclass","requirement","icon","simulink_requirementsFT","color","red","group","Requirement Artifacts");
            map("mwreq_item") = struct("superclass","requirement_item","icon","documentText","color","red","group","Requirement Artifacts");
            
            % link superclass
            map("mwreq_link") = struct("superclass","link","icon","linkUI","color","","group","");
            map("mwreq_link_file") = struct("superclass","link","icon","linkFile","color","","group","");

            % stateflow superclass
            map("sf_chart") = struct("superclass","stateflow","icon","stateflowChart","color","blue","group","Design Artifacts");
            map("sf_graphical_fcn") = struct("superclass","stateflow","icon","stateflowGraphicalFunction","color","blue","group","Design Artifacts");
            map("sf_group") = struct("superclass","stateflow","icon","stateflowBox","color","blue","group","Design Artifacts");
            map("sf_state") = struct("superclass","stateflow","icon","stateflowState","color","blue","group","Design Artifacts");
            map("sf_state_transition_chart") = struct("superclass","stateflow","icon","stateflowTransitionTable","color","blue","group","Design Artifacts");
            map("sf_truth_table_chart") = struct("superclass","stateflow","icon","stateflowTruthTable","color","blue","group","Design Artifacts");

            % design superclass
            map("sl_block_diagram") = struct("superclass","design","icon","simulink","color","blue","group","Design Artifacts");
            map("sl_embedded_matlab_fcn") = struct("superclass","design","icon","matlab_block","color","blue","group","Design Artifacts");
            map("sl_model_reference") = struct("superclass","design","icon","modelReference","color","blue","group","Design Artifacts");
            map("sl_protected_block_diagram") = struct("superclass","design","icon","simulink","color","blue","group","Design Artifacts");
            map("sl_ref") = struct("superclass","design","icon","link_simulinkLibrary","color","blue","group","Design Artifacts");
            map("sl_req_table") = struct("superclass","design","icon","requirementsTable","color","red","group","Requirement Artifacts");
            map("sl_subsystem") = struct("superclass","design","icon","subsystem","color","blue","group","Design Artifacts");
            map("sl_subsystem_reference") = struct("superclass","design","icon","subsystemReference","color","blue","group","Design Artifacts");
            map("sl_library_file") = struct("superclass","design","icon","simulinkLibrary","color","blue","group","Design Artifacts");
            map("sl_model_file") = struct("superclass","design","icon","documentSimulink","color","blue","group","Design Artifacts");
            map("sl_protected_model_file") = struct("superclass","design","icon","documentSimulinkLock","color","blue","group","Design Artifacts");
            map("sl_subsystem_file") = struct("superclass","design","icon","documentSimulinkSubsystem","color","blue","group","Design Artifacts");
            
            % harness superclass
            map("sl_harness_block_diagram") = struct("superclass","harness","icon","testHarness","color","purple","group","Test Artifacts");
            map("sl_harness_cut") = struct("superclass","harness","icon","highlightComponentUnderTest","color","purple","group","Test Artifacts");
            map("sl_matlab_ref") = struct("superclass","harness","icon","matlab_highlightCurrentLine","color","purple","group","Test Artifacts");
            map("harness_info") = struct("superclass","harness","icon","","color","purple","group","Test Artifacts");
            map("harness_info_file") = struct("superclass","harness","icon","documentWeb","color","purple","group","Test Artifacts");
            map("harness_link") = struct("superclass","harness","icon","","color","purple","group","Test Artifacts");
            map("sl_harness_file") = struct("superclass","harness","icon","documentSimulink","color","purple","group","Test Artifacts");

            % dictionary superclass
            map("sl_data_dictionary_file") = struct("superclass","dictionary","icon","database","color","darkcyan","group","Interface Artifacts");
            map("sl_data_dictionary_signal") = struct("superclass","dictionary","icon","wsSignal","color","darkcyan","group","Interface Artifacts");
            map("sl_data_dictionary_bus") = struct("superclass","dictionary","icon","bus","color","darkcyan","group","Interface Artifacts");
            map("sl_data_dictionary_buselem") = struct("superclass","dictionary","icon","typeBusElement","color","darkcyan","group","Interface Artifacts");

            % architecture
            map("zc_block_diagram") = struct("superclass","architecture","icon","systemComposer","color","green","group","Architecture Artifacts");
            map("zc_component") = struct("superclass","architecture","icon","singleTile","color","green","group","Architecture Artifacts");
            map("zc_file") = struct("superclass","architecture","icon","documentSystemComposer","color","green","group","Architecture Artifacts");
            map("zc_allocation") = struct("superclass","architecture","icon","allocationSet","color","green","group","Architecture Artifacts");
            map("mw_profile_file") = struct("superclass","architecture","icon","profile_function","color","green","group","Architecture Artifacts");
            map("zc_stereo") = struct("superclass","architecture","icon","profile_function","color","green","group","Architecture Artifacts");
            map("zc_property") = struct("superclass","architecture","icon","add_callbackProperty","color","green","group","Architecture Artifacts");
            map("zc_view") = struct("superclass","architecture","icon","architectureViewUI","color","green","group","Architecture Artifacts");
            map("zc_sequence") = struct("superclass","architecture","icon","sequenceDiagramUI","color","green","group","Architecture Artifacts");
            map("zc_sw_arch") = struct("superclass","architecture","icon","functionDiagramUI","color","green","group","Architecture Artifacts");
            map("zc_refcomp") = struct("superclass","architecture","icon","modelRefWindowUI","color","green","group","Architecture Artifacts");
            map("zc_activity_diagram") = struct("superclass","architecture","icon","stateflow_FT","color","green","group","Architecture Artifacts");
            map("zc_allocation_scenario") = struct("superclass","architecture","icon","allocationScenario","color","black","green","Architecture Artifacts");
            map("zc_allocation_set") = struct("superclass","architecture","icon","allocationSet","color","black","green","Architecture Artifacts");
            map("zc_allocation_set_file") = struct("superclass","architecture","icon","allocationScenario","color","black","green","Architecture Artifacts");
            
            % safety_security
            map("sfa_conditional") = struct("superclass","saftey_security","icon","edit_condition","color","darkorange","group","Safety&Security Artifacts");
            map("sfa_fault") = struct("superclass","saftey_security","icon","blueLightning","color","darkorange","group","Safety&Security Artifacts");
            map("sfa_fault_info_file") = struct("superclass","saftey_security","icon","transform_documentScript","color","darkorange","group","Safety&Security Artifacts");
            map("sam_cell_value") = struct("superclass","saftey_security","icon","tableHeaderHighlighted","color","darkorange","group","Safety&Security Artifacts");
            map("sam_table_file") = struct("superclass","saftey_security","icon","safetyAnalyzerApp","color","darkorange","group","Safety&Security Artifacts");
            map("sam_table_row") = struct("superclass","saftey_security","icon","tableHeaderHighlighted","color","darkorange","group","Safety&Security Artifacts");

            % test
            map("mtest_activity") = struct("superclass","test","icon","testClass","color","purple","group","Test Artifacts");
            map("mtest_result") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("mtest_result_file") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_seq") = struct("superclass","test","icon","check_numberList","color","purple","group","Test Artifacts");
            map("sl_test_case_result") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_file_result") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_iteration_result") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_result_file") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_resultset") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_session_result_file") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_suite_result") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_assessment") = struct("superclass","test","icon","testClass","color","purple","group","Test Artifacts");
            map("sl_test_case") = struct("superclass","test","icon","testBrowserApp","color","purple","group","Test Artifacts");
            map("sl_test_file") = struct("superclass","test","icon","tests","color","purple","group","Test Artifacts");
            map("sl_test_file_element") = struct("superclass","test","icon","tests","color","purple","group","Test Artifacts");
            map("sl_test_iteration") = struct("superclass","test","icon","tests","color","purple","group","Test Artifacts");
            map("sl_test_suite") = struct("superclass","test","icon","folder_tests","color","purple","group","Test Artifacts");
            map("mldatx_file") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");
            map("sl_test_file_element_result") = struct("superclass","test","icon","check_table","color","purple","group","Test Artifacts");

            % other
            map("mw_code_analyzer_cfg_file") = struct("superclass","other","icon","documentBraces","color","black","group","Other Artifacts");
            map("mwreq_text_range") = struct("superclass","other","icon","highlightCurrentLine","color","black","group","Other Artifacts");
            map("mat_file") = struct("superclass","other","icon","workspace","color","black","group","Other Artifacts");
            map("sl_signal_editor") = struct("superclass","other","icon","edit_task","color","black","group","Other Artifacts");
           
            % external
            map("cvf_file") = struct("superclass","external","icon","documentation","color","black","group","Other Artifacts");
            map("xls_file") = struct("superclass","external","icon","documentation","color","black","group","Other Artifacts");
            map("doc") = struct("superclass","external","icon","documentation","color","black","group","Other Artifacts");

            % folder
            map("folder") = struct("superclass","folder","icon","packageFolder","color","","group","");

            % project
            map("top_proj") = struct("superclass","project","icon","project","color","","group","");
            map("ref_proj") = struct("superclass","project","icon","link_project","color","","group","");
        end
    end
end

