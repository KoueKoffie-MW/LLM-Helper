a.rootNode.children
b = jsonencode(a.rootNode.children);
% Write the JSON file to disc
fileID = fopen('ProjectStructure.json.txt', 'w');
fwrite(fileID, b, 'char');
fclose(fileID);