with open('lib/screens/truck_maintenance_screen.dart', 'rb') as f:
    lines = f.read().split(b'\n')

for i in [269, 432]:
    line = lines[i]
    print(f'Line {i+1} length: {len(line)}')
    for col in [20, 21, 22, 23]:
        if col < len(line):
            b = line[col]
            print(f'  col {col}: 0x{b:02x} ({chr(b) if 32 <= b < 127 else "non-printable"})')
