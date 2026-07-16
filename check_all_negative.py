import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('lib/screens/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i in range(148, 257):
    line = lines[i]
    for ch in line:
        if ch in '([{':
            balance += 1
        elif ch in ')]}':
            balance -= 1
    if balance < 0:
        print(f'Negative at line {i+1}: balance={balance}')

print(f'Balance at line 256: {balance}')
