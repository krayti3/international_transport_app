import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('lib/screens/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i in range(148, 256):
    line = lines[i]
    for ch in line:
        if ch in '([{':
            balance += 1
        elif ch in ')]}':
            balance -= 1
    print(f'Line {i+1}: balance={balance}')

print(f'Final balance at line 256: {balance}')
