import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('lib/screens/truck_maintenance_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i in range(321, 436):
    line = lines[i]
    for ch in line:
        if ch == '(':
            balance += 1
        elif ch == ')':
            balance -= 1
    print(f'Line {i+1}: balance={balance}')

print(f'Final balance at line 436: {balance}')
