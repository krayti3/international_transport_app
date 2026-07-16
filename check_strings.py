with open('lib/screens/truck_maintenance_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

in_block_comment = False
in_string = False
string_char = None
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('//'):
        continue
    
    j = 0
    while j < len(line):
        ch = line[j]
        
        if in_block_comment:
            if ch == '*' and j + 1 < len(line) and line[j + 1] == '/':
                in_block_comment = False
                j += 2
                continue
        elif in_string:
            if ch == '\\':
                j += 2
                continue
            if ch == string_char:
                in_string = False
                string_char = None
        else:
            if ch == '/' and j + 1 < len(line) and line[j + 1] == '*':
                in_block_comment = True
                j += 2
                continue
            if ch == '/' and j + 1 < len(line) and line[j + 1] == '/':
                break
            if ch in '"\'':
                in_string = True
                string_char = ch
        
        j += 1
    
    if in_block_comment:
        print(f'Block comment starts at line {i+1} and is not closed')
    if in_string:
        print(f'String starts at line {i+1} and is not closed')

print('Done checking comments and strings')
