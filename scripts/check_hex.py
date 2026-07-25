with open('lib/screens/truck_maintenance_screen.dart', 'rb') as f:
    lines = f.read().split(b'\n')
for i in [328, 329, 330, 331]:
    line = lines[i]
    print(f'Line {i+1} ({len(line)} bytes):')
    hex_str = ' '.join(f'{b:02x}' for b in line[:60])
    print(f'  Hex: {hex_str}')
    print(f'  Str: {repr(line.decode("utf-8", errors="replace"))}')
