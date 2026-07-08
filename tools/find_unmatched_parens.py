from pathlib import Path
s=Path('lib/main.dart').read_text()
stack=[]
pairs={'(':')','[':']','{':'}'}
openers=set(pairs.keys())
closers={v:k for k,v in pairs.items()}
for i,ch in enumerate(s, start=1):
    if ch in openers:
        stack.append((ch,i))
    elif ch in closers:
        if stack and stack[-1][0]==closers[ch]:
            stack.pop()
        else:
            print('Unmatched closer',ch,'at',i)
            break
else:
    if stack:
        print('Unmatched opener',stack[-1][0],'at',stack[-1][1])
    else:
        print('All balanced')

# print nearby context for unmatched opener if any
if stack:
    pos=stack[-1][1]
    start=max(1,pos-80)
    end=min(len(s), pos+80)
    snippet=s[start-1:end]
    print('\nContext around position',pos,':\n',snippet)
