import sys
import re

def split_manifest(input_file, crd_file, other_file):
    with open(input_file, 'r') as f:
        content = f.read()

    # Split by rigid separator
    docs = re.split(r'^---$', content, flags=re.MULTILINE)
    crds = []
    others = []

    for doc in docs:
        if not doc.strip():
            continue
        # Check if it is a CRD
        # We look for "kind: CustomResourceDefinition"
        if re.search(r'^kind:\s*CustomResourceDefinition', doc, re.MULTILINE):
            crds.append(doc)
        else:
            others.append(doc)

    print(f"Found {len(crds)} CRDs and {len(others)} other resources.")

    with open(crd_file, 'w') as f:
        f.write('\n---\n'.join(crds))

    with open(other_file, 'w') as f:
        f.write('\n---\n'.join(others))

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python split.py <input> <crd_output> <other_output>")
        sys.exit(1)

    split_manifest(sys.argv[1], sys.argv[2], sys.argv[3])
