import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('lib/screens/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i in range(0, 102):
    line = lines[i]
    for ch in line:
        if ch in '([{':
            balance += 1
        elif ch in ')]}':
            balance -= 1

print(f'Balance before build method (line 102): {balance}')

balance2 = 0
for i in range(102, len(lines)):
    line = lines[i]
    for ch in line:
        if ch in '([{':
            balance2 += 1
        elif ch in ')]}':
            balance2 -= 1

print(f'Balance from build method to end: {balance2}')
print(f'Total balance: {balance + balance2}')
print(f'Total lines: {len(lines)}')
