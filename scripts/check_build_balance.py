import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('lib/screens/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i in range(102, 257):
    line = lines[i]
    for ch in line:
        if ch in '([{':
            balance += 1
        elif ch in ')]}':
            balance -= 1
    if i >= 243 and i <= 256:
        print(f'Line {i+1}: balance={balance}')

print(f'Balance at line 257: {balance}')
