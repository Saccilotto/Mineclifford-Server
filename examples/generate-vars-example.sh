#!/bin/bash
# Example: Generate Ansible variables using Version Manager

# Example 1: Latest Paper server with 4GB RAM
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version latest \
  --java-memory 4G \
  --java-gamemode survival \
  --java-difficulty normal \
  -o deployment/ansible/minecraft_vars.yml

echo "Generated vars for latest Paper server"

# Example 2: Specific Paper version
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version 1.20.1-196 \
  --java-memory 2G \
  --java-gamemode creative \
  --java-difficulty easy \
  -o deployment/ansible/minecraft_vars_paper_1201.yml

echo "Generated vars for Paper 1.20.1-196"

# Example 3: Forge server with Bedrock
python3 src/ansible_integration.py generate \
  --java-type forge \
  --java-version latest \
  --java-memory 6G \
  --bedrock \
  --bedrock-version latest \
  -o deployment/ansible/minecraft_vars_forge_bedrock.yml

echo "Generated vars for Forge with Bedrock"

# Example 4: Vanilla server
python3 src/ansible_integration.py generate \
  --java-type vanilla \
  --java-version 1.21.4 \
  --java-memory 2G \
  --java-gamemode survival \
  --java-difficulty hard \
  -o deployment/ansible/minecraft_vars_vanilla.yml

echo "Generated vars for Vanilla 1.21.4"

echo ""
echo "All example configurations generated!"
echo "Check deployment/ansible/ for generated files"
