#!/bin/bash

# Generate BasicAuth password hash for Traefik
# Usage: ./scripts/generate-basicauth.sh <username> <password>

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -ne 2 ]; then
    echo -e "${YELLOW}Usage: $0 <username> <password>${NC}"
    echo ""
    echo "Example: $0 admin mySecureP@ssw0rd"
    echo ""
    echo "This will generate a bcrypt hash suitable for Traefik BasicAuth"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

echo -e "${BLUE}Generating BasicAuth hash...${NC}"

# Check if htpasswd is available (from apache2-utils)
if command -v htpasswd &> /dev/null; then
    # Use htpasswd to generate bcrypt hash
    HASH=$(htpasswd -nbB "$USERNAME" "$PASSWORD")
    echo ""
    echo -e "${GREEN}Generated hash:${NC}"
    echo "$HASH"
    echo ""
    echo -e "${YELLOW}Add this to your .env file:${NC}"
    echo "TRAEFIK_DASHBOARD_USER=admin"
    # Escape $ characters for .env file
    ESCAPED_HASH=$(echo "$HASH" | sed 's/\$/\$\$/g')
    echo "TRAEFIK_DASHBOARD_PASSWORD_HASH=$ESCAPED_HASH"

elif command -v docker &> /dev/null; then
    # Use Docker with httpd image to generate hash
    echo -e "${YELLOW}htpasswd not found, using Docker...${NC}"
    HASH=$(docker run --rm httpd:alpine htpasswd -nbB "$USERNAME" "$PASSWORD")
    echo ""
    echo -e "${GREEN}Generated hash:${NC}"
    echo "$HASH"
    echo ""
    echo -e "${YELLOW}Add this to your .env file:${NC}"
    echo "TRAEFIK_DASHBOARD_USER=admin"
    # Escape $ characters for .env file
    ESCAPED_HASH=$(echo "$HASH" | sed 's/\$/\$\$/g')
    echo "TRAEFIK_DASHBOARD_PASSWORD_HASH=$ESCAPED_HASH"

else
    echo -e "${YELLOW}Neither htpasswd nor Docker found.${NC}"
    echo ""
    echo "Please install apache2-utils to use htpasswd:"
    echo "  Ubuntu/Debian: sudo apt-get install apache2-utils"
    echo "  macOS: brew install httpd"
    echo ""
    echo "Or install Docker and try again."
    exit 1
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo -e "${YELLOW}Note: The password is double-escaped (\$\$) for docker-compose compatibility.${NC}"
