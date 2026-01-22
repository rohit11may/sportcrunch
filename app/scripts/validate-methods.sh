#!/bin/bash
#
# validate-methods.sh
# Validates JSON-Swift parallelism and generates _index.json
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation failed (missing Swift implementation or invalid JSON)
#
# Usage: ./scripts/validate-methods.sh
#

set -e

METHODS_DIR="app/methods"
INDEX_FILE="$METHODS_DIR/_index.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Validating method registry..."

# Track errors
ERRORS=0

# Initialize index structure
INDEX_FAMILIES=()

# Find all method families (directories with _family.json)
for family_dir in "$METHODS_DIR"/*/; do
    family_name=$(basename "$family_dir")
    family_json="$family_dir/_family.json"

    # Skip if no _family.json
    if [[ ! -f "$family_json" ]]; then
        continue
    fi

    echo "Family: $family_name"

    # Validate _family.json
    if ! python3 -m json.tool < "$family_json" > /dev/null 2>&1; then
        echo -e "${RED}   Invalid JSON: $family_json${NC}"
        ((ERRORS++))
        continue
    fi

    # Parse family metadata
    FAMILY_NAME=$(python3 -c "import json; print(json.load(open('$family_json'))['name'])" 2>/dev/null || echo "")
    FAMILY_DESC=$(python3 -c "import json; print(json.load(open('$family_json'))['description'])" 2>/dev/null || echo "")

    VERSION_ENTRIES=()

    # Find all versions in this family
    for version_dir in "$family_dir"*/; do
        version_name=$(basename "$version_dir")

        # Skip configs directory and hidden directories
        if [[ "$version_name" == "configs" ]] || [[ "$version_name" == .* ]]; then
            continue
        fi

        method_json="$version_dir/method.json"

        # Check if method.json exists
        if [[ ! -f "$method_json" ]]; then
            continue
        fi

        echo "   Version: $version_name"

        # Validate method.json
        if ! python3 -m json.tool < "$method_json" > /dev/null 2>&1; then
            echo -e "${RED}      Invalid JSON: $method_json${NC}"
            ((ERRORS++))
            continue
        fi

        # Extract swiftClass from method.json
        SWIFT_CLASS=$(python3 -c "import json; print(json.load(open('$method_json'))['swiftClass'])" 2>/dev/null || echo "")

        if [[ -z "$SWIFT_CLASS" ]]; then
            echo -e "${RED}      Missing swiftClass in $method_json${NC}"
            ((ERRORS++))
            continue
        fi

        # Check for matching Swift file
        SWIFT_FILE="$version_dir/${SWIFT_CLASS}.swift"

        if [[ ! -f "$SWIFT_FILE" ]]; then
            echo -e "${RED}      Missing Swift implementation: $SWIFT_FILE${NC}"
            echo -e "${RED}         method.json references swiftClass '$SWIFT_CLASS' but no ${SWIFT_CLASS}.swift found${NC}"
            ((ERRORS++))
            continue
        fi

        echo -e "${GREEN}      Swift: ${SWIFT_CLASS}.swift${NC}"

        # Find configs for this version
        CONFIGS=()
        configs_dir="$version_dir/configs"
        if [[ -d "$configs_dir" ]]; then
            for config_file in "$configs_dir"/*.config.json; do
                if [[ -f "$config_file" ]]; then
                    config_name=$(basename "$config_file")

                    # Validate config JSON
                    if ! python3 -m json.tool < "$config_file" > /dev/null 2>&1; then
                        echo -e "${RED}      Invalid config JSON: $config_file${NC}"
                        ((ERRORS++))
                        continue
                    fi

                    CONFIGS+=("\"$config_name\"")
                    echo -e "${GREEN}      Config: $config_name${NC}"
                fi
            done
        fi

        # Get method metadata
        METHOD_NAME=$(python3 -c "import json; print(json.load(open('$method_json'))['name'])" 2>/dev/null || echo "$SWIFT_CLASS")
        METHOD_DESC=$(python3 -c "import json; print(json.load(open('$method_json')).get('description', ''))" 2>/dev/null || echo "")
        DEFAULT_CONFIG=$(python3 -c "import json; print(json.load(open('$method_json')).get('defaultConfig', 'default.config.json'))" 2>/dev/null || echo "default.config.json")

        # Build version entry
        CONFIGS_JSON=$(IFS=,; echo "[${CONFIGS[*]}]")
        VERSION_ENTRY=$(cat <<EOF
      {
        "version": "$version_name",
        "name": "$METHOD_NAME",
        "description": "$METHOD_DESC",
        "swiftClass": "$SWIFT_CLASS",
        "defaultConfig": "$DEFAULT_CONFIG",
        "configs": $CONFIGS_JSON
      }
EOF
)
        VERSION_ENTRIES+=("$VERSION_ENTRY")
    done

    # Build family entry
    if [[ ${#VERSION_ENTRIES[@]} -gt 0 ]]; then
        VERSIONS_JSON=$(IFS=,; echo "${VERSION_ENTRIES[*]}")
        FAMILY_ENTRY=$(cat <<EOF
  {
    "family": "$FAMILY_NAME",
    "description": "$FAMILY_DESC",
    "versions": [
$VERSIONS_JSON
    ]
  }
EOF
)
        INDEX_FAMILIES+=("$FAMILY_ENTRY")
    fi
done

# Check for errors before generating index
if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo -e "${RED}Validation failed with $ERRORS error(s)${NC}"
    echo -e "${RED}   Fix the above issues and re-run validation${NC}"
    exit 1
fi

# Generate _index.json
echo ""
echo "Generating $INDEX_FILE..."

FAMILIES_JSON=$(IFS=,; echo "${INDEX_FAMILIES[*]}")

cat > "$INDEX_FILE" << EOF
{
  "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "families": [
$FAMILIES_JSON
  ]
}
EOF

# Validate generated index
if python3 -m json.tool < "$INDEX_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}Generated valid _index.json${NC}"
else
    echo -e "${RED}Generated _index.json is invalid!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Method registry validation complete${NC}"
echo "  Families: ${#INDEX_FAMILIES[@]}"
echo "  Index: $INDEX_FILE"
