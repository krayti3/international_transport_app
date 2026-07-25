with open('lib/screens/truck_maintenance_screen.dart', 'rb') as f:
    lines = f.read().split(b'\n')
for i in [328, 329, 330, 331, 431, 432, 433, 434]:
    line = lines[i]
    print(f'Line {i+1} last 5 bytes: {line[-5:]}')
    print(f'Line {i+1} last char: {chr(line[-1]) if line else "empty"}')
