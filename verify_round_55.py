import os
import re

def verify_docs():
    root = "/root/starter/docs"
    errors = []
    
    # 1. Terminology Check
    term_pattern = re.compile(r'(制品 \(Artifact\) \(Artifact\)|Wish Platform Platform|求解器 \(Solver\) \(Solver\))')
    
    for dirpath, _, filenames in os.walk(root):
        for f in filenames:
            if not f.endswith('.md'): continue
            path = os.path.join(dirpath, f)
            with open(path, 'r') as file:
                content = file.read()
                
                # Check Terms
                if term_pattern.search(content):
                    errors.append(f"[TERM] Stacked terms found in {path}")
                    
                # Check Links
                links = re.findall(r'\[.*?\]\((.*?)\)', content)
                for link in links:
                    if link.startswith('http') or link.startswith('#') or link.startswith('mailto'): continue
                    # Simple resolution
                    target = os.path.normpath(os.path.join(dirpath, link.split('#')[0]))
                    if not os.path.exists(target):
                        errors.append(f"[LINK] Broken link in {path}: {link}")

    if errors:
        print("\n".join(errors))
        exit(1)
    else:
        print("Verification Passed: No broken links or terminology errors.")

if __name__ == "__main__":
    verify_docs()
