% Class to define properties of each tree node. It contains a method to add
% node children of a given node and a method to find a given node based on
% single or multiple properties (in AND logic)
%
% Copyright 1984-2025 The MathWorks, Inc


classdef TreeNode < handle
    properties
        Text
        NodeData
        fullpath
        path
        type
        superclassType
        label
        project
        Icon
        almobject
        children
        multiplicity
    end
    methods

        % Class constructor to create the Tree object
        function obj = TreeNode(varargin)
            if nargin > 0
                obj.children = feval(class(obj));
                obj.children(:) = []; 
                for k = 1:2:length(varargin)
                    if isprop(obj, varargin{k})
                        obj.(varargin{k}) = varargin{k+1};
                    end
                end
            end
        end
        
        % Function to add a child to the tree object
        function addchilds(obj, child)
            obj.children(end+1) = child;
        end
        
        % Function to find a node in the tree based on search properties
        function node = findObj(obj, propVals)
            node = [];  % Default return value if not found

            % Handle empty propVals
            if isempty(propVals)
                propVals = struct('NodeData', []);
            end

            % Convert containers.Map to struct if needed
            if isa(propVals, 'containers.Map')
                keys = propVals.keys;
                vals = propVals.values;
                propStruct = struct();
                for i = 1:numel(keys)
                    propStruct.(keys{i}) = vals{i};
                end
                propVals = propStruct;
            end

            props = fieldnames(propVals);

            % Optimized BFS queue using explicit head/tail pointers
            initialQueueSize = 1000000;
            queue = cell(1, initialQueueSize); % preallocate
            head = 1;
            tail = 2;
            queue{1} = obj;

            while head < tail
                current = queue{head};
                head = head + 1;

                % Check if all properties match
                match = true;
                for i = 1:numel(props)
                    if ~isprop(current, props{i}) || ~isequal(current.(props{i}), propVals.(props{i}))
                        match = false;
                        break;
                    end
                end

                % If match found, return the node
                if match
                    node = current;
                    return;
                end

                % Add children to the queue (if any)
                if isprop(current, 'children') && ~isempty(current.children)
                    childrenObj = current.children;
                    nChildren = numel(childrenObj);
                    % Expand queue if needed
                    if tail + nChildren - 1 > numel(queue)
                        queue{end+1:tail+nChildren+127} = [];
                    end
                    for k = 1:nChildren
                        queue{tail} = childrenObj(k);
                        tail = tail + 1;
                    end
                end
            end
        end

        % Function to remove a given node
        function tf = removeNodeByObject(obj, nodeToRemove)
            % Remove nodeToRemove from the tree rooted at obj.
            % Returns true if successful, false otherwise.
            if obj == nodeToRemove
                % Cannot remove the root node itself
                tf = false;
                return;
            end

            % Use BFS to find the parent of nodeToRemove
            queue = {obj};
            head = 1;
            tail = 2;

            while head < tail
                current = queue{head};
                head = head + 1;

                childrenObj = current.children;
                if ~isempty(childrenObj)
                    % Find the index of nodeToRemove in children
                    idx = find(childrenObj == nodeToRemove, 1);
                    if ~isempty(idx)
                        current.children(idx) = [];
                        tf = true;
                        return;
                    end
                    % Add children to the queue
                    for k = 1:numel(childrenObj)
                        queue{tail} = childrenObj(k);
                        tail = tail + 1;
                    end
                end
            end

            % If we reach here, node was not found
            tf = false;
        end
    end
end