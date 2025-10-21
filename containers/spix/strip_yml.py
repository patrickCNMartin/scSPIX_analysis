#!/usr/bin/env python3
"""Strip build strings from conda environment YML file."""

import yaml
import sys

def strip_build_strings(yml_file, output_file=None):
    """
    Read a conda environment YML file and remove build strings from conda dependencies.
    Build strings are the part after the second '=' sign (e.g., hda65f42_8 in bzip2=1.0.8=hda65f42_8)
    """
    
    # Load the YML file
    with open(yml_file, 'r') as f:
        env = yaml.safe_load(f)
    
    # Process conda dependencies
    if 'dependencies' in env:
        new_deps = []
        for dep in env['dependencies']:
            if isinstance(dep, str):
                # Split by '=' to find the build string
                parts = dep.split('=')
                if len(parts) >= 3:
                    # Remove build string (keep only name and version)
                    cleaned = f"{parts[0]}={parts[1]}"
                    new_deps.append(cleaned)
                else:
                    # Keep as-is if no build string
                    new_deps.append(dep)
            else:
                # If it's a dict (like pip section), keep as-is
                new_deps.append(dep)
        
        env['dependencies'] = new_deps
    
    # Determine output file
    if output_file is None:
        output_file = yml_file.replace('.yml', '_cleaned.yml')
    
    # Write the cleaned YML file
    with open(output_file, 'w') as f:
        yaml.dump(env, f, default_flow_style=False, sort_keys=False)
    
    print(f"✓ Cleaned YML file written to: {output_file}")
    return output_file

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python strip_yml.py <input_yml_file> [output_yml_file]")
        print("Example: python strip_yml.py spix_1007.yml spix_1007_cleaned.yml")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        strip_build_strings(input_file, output_file)
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)