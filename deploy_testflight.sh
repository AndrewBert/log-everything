#!/bin/bash

# TestFlight Deployment Script for Log Splitter
# Automates the build and upload process to TestFlight

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Log Splitter"
BUNDLE_ID="com.andrewbertino.logeverything"
IPA_PATH="build/ios/ipa/myapp.ipa"
BETA_TESTERS_FILE="beta_testers.txt"  # File containing email addresses, one per line

# Functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if we're in a Flutter project
check_flutter_project() {
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Not in a Flutter project directory"
        exit 1
    fi
}

# Check if xcrun is available (for App Store uploads)
check_xcode_tools() {
    if ! command -v xcrun &> /dev/null; then
        print_error "Xcode command line tools not found. Please install Xcode."
        exit 1
    fi
}

# Ask for version bump
ask_version_bump() {
    echo -e "${YELLOW}Current version:${NC} $(grep '^version:' pubspec.yaml | cut -d' ' -f2)"
    read -p "Do you want to bump the version? (y/N): " bump_version
    
    if [[ $bump_version =~ ^[Yy]$ ]]; then
        read -p "Enter new version (e.g., 1.2.0+5): " new_version
        if [ ! -z "$new_version" ]; then
            sed -i '' "s/^version:.*/version: $new_version/" pubspec.yaml
            print_success "Version updated to $new_version"
        fi
    fi
}

# Clean and prepare
clean_build() {
    print_step "Cleaning previous builds..."
    flutter clean
    flutter pub get
    print_success "Clean completed"
}

# Run analysis
run_analysis() {
    print_step "Running Flutter analysis..."
    if flutter analyze; then
        print_success "Analysis passed"
    else
        print_error "Analysis failed. Please fix issues before deploying."
        exit 1
    fi
}

# Build IPA
build_ipa() {
    print_step "Building IPA for release..."
    if flutter build ipa --release; then
        print_success "IPA build completed"
    else
        print_error "IPA build failed"
        exit 1
    fi
}

# Upload to TestFlight
upload_testflight() {
    print_step "Uploading to TestFlight..."
    
    # Check if IPA exists
    if [ ! -f "$IPA_PATH" ]; then
        print_error "IPA file not found at $IPA_PATH"
        exit 1
    fi
    
    # Check for authentication method
    if [ ! -z "$APP_STORE_CONNECT_API_KEY_ID" ] && [ ! -z "$APP_STORE_CONNECT_API_ISSUER_ID" ]; then
        # Use API Key authentication (altool will look in standard locations)
        print_step "Using App Store Connect API Key authentication..."
        xcrun altool --upload-app -f "$IPA_PATH" -t ios \
            --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
            --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
    elif [ ! -z "$APP_STORE_CONNECT_USERNAME" ] && [ ! -z "$APP_STORE_CONNECT_PASSWORD" ]; then
        # Use username/password authentication
        print_step "Using username/password authentication..."
        xcrun altool --upload-app -f "$IPA_PATH" -t ios \
            -u "$APP_STORE_CONNECT_USERNAME" \
            -p "$APP_STORE_CONNECT_PASSWORD"
    else
        print_error "No authentication method configured."
        print_error "Please set up either:"
        print_error "1. API Key: APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID, APP_STORE_CONNECT_API_KEY_PATH"
        print_error "2. Username/Password: APP_STORE_CONNECT_USERNAME, APP_STORE_CONNECT_PASSWORD"
        print_error ""
        print_error "See setup instructions in the script comments."
        exit 1
    fi
    
    print_success "Upload to TestFlight completed!"
}

# Get JWT token for App Store Connect API
get_jwt_token() {
    if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_API_ISSUER_ID" ]; then
        print_error "API Key authentication not configured for beta tester management"
        return 1
    fi
    
    # Check if jwt command line tool is available
    if ! command -v jwt &> /dev/null; then
        print_warning "jwt CLI tool not found. Installing via npm..."
        if command -v npm &> /dev/null; then
            npm install -g jsonwebtoken-cli
        else
            print_error "npm not found. Please install Node.js or manually install jwt CLI tool"
            return 1
        fi
    fi
    
    # Generate JWT token
    jwt sign --key ~/.appstoreconnect/private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8 \
        --alg ES256 \
        --iss "$APP_STORE_CONNECT_API_ISSUER_ID" \
        --exp 1200 \
        --aud appstoreconnect-v1 | tr -d '\n'
}

# Get app ID from App Store Connect
get_app_id() {
    local jwt_token="$1"
    
    print_step "Getting app ID from App Store Connect..."
    
    local response=$(curl -s \
        -H "Authorization: Bearer $jwt_token" \
        -H "Content-Type: application/json" \
        "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=$BUNDLE_ID")
    
    # Extract app ID using basic text processing (avoiding jq dependency)
    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Auto-assign build to beta group
assign_build_to_beta_group() {
    local jwt_token=$(get_jwt_token)
    if [ $? -ne 0 ] || [ -z "$jwt_token" ]; then
        print_error "Failed to get JWT token for API access"
        return 1
    fi
    
    local app_id=$(get_app_id "$jwt_token")
    if [ -z "$app_id" ]; then
        print_error "Could not find app with bundle ID: $BUNDLE_ID"
        return 1
    fi
    
    print_step "Finding latest build..."
    
    # Get the latest build
    local builds_response=$(curl -s \
        -H "Authorization: Bearer $jwt_token" \
        -H "Content-Type: application/json" \
        "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=$app_id&sort=-version&limit=1")
    
    local build_id=$(echo "$builds_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$build_id" ]; then
        print_error "Could not find latest build"
        return 1
    fi
    
    print_success "Found latest build ID: $build_id"
    
    # Get beta groups for this app
    print_step "Finding beta groups..."
    local groups_response=$(curl -s \
        -H "Authorization: Bearer $jwt_token" \
        -H "Content-Type: application/json" \
        "https://api.appstoreconnect.apple.com/v1/betaGroups?filter[app]=$app_id")
    
    # Look for a group named "Beta Testers!", "Automation testers", or similar
    local group_names=("Beta Testers!" "beta testers!" "Beta Testers" "beta testers" "Automation testers" "automation testers" "Beta" "beta" "Testers" "testers")
    local group_id=""
    
    for group_name in "${group_names[@]}"; do
        group_id=$(echo "$groups_response" | grep -B5 -A5 "\"name\":\"$group_name\"" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ ! -z "$group_id" ]; then
            print_success "Found beta group '$group_name' with ID: $group_id"
            break
        fi
    done
    
    if [ -z "$group_id" ]; then
        print_warning "No standard beta group found. Available groups:"
        echo "$groups_response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  - /'
        print_warning "You may need to manually assign the build in App Store Connect"
        return 0
    fi
    
    # Assign build to beta group
    print_step "Assigning build to beta group..."
    local assign_response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $jwt_token" \
        -H "Content-Type: application/json" \
        -d "{
            \"data\": [
                {
                    \"type\": \"builds\",
                    \"id\": \"$build_id\"
                }
            ]
        }" \
        "https://api.appstoreconnect.apple.com/v1/betaGroups/$group_id/relationships/builds")
    
    local http_code="${assign_response: -3}"
    
    if [ "$http_code" = "204" ]; then
        print_success "✓ Build assigned to beta group successfully!"
        print_success "✓ Your public TestFlight link should now include this build"
    else
        print_warning "! Failed to assign build to beta group (HTTP $http_code)"
        print_warning "! You may need to manually assign it in App Store Connect"
    fi
}

# Ask about beta group assignment
ask_beta_group_assignment() {
    echo -e "${YELLOW}Beta Testing Setup:${NC}"
    echo "This script can automatically assign the new build to your existing beta group"
    echo "(for users who join via your public TestFlight link)."
    echo ""
    read -p "Do you want to auto-assign this build to your beta group? (Y/n): " assign_build
    
    if [[ ! $assign_build =~ ^[Nn]$ ]]; then
        assign_build_to_beta_group
    else
        print_warning "Skipping beta group assignment. You'll need to manually assign the build in App Store Connect."
    fi
}

# Print setup instructions
print_setup_instructions() {
    echo -e "${YELLOW}SETUP INSTRUCTIONS:${NC}"
    echo ""
    echo "Before using this script, you need to configure authentication:"
    echo ""
    echo "METHOD 1 - API Key (Recommended):"
    echo "1. Create an App Store Connect API Key:"
    echo "   - Go to App Store Connect > Users and Access > Keys"
    echo "   - Create a new API key with App Manager role"
    echo "   - Download the .p8 file"
    echo ""
    echo "2. Set environment variables:"
    echo "   export APP_STORE_CONNECT_API_KEY_ID='your-key-id'"
    echo "   export APP_STORE_CONNECT_API_ISSUER_ID='your-issuer-id'"
    echo "   export APP_STORE_CONNECT_API_KEY_PATH='/path/to/your/key.p8'"
    echo ""
    echo "METHOD 2 - App-Specific Password:"
    echo "1. Generate an app-specific password at appleid.apple.com"
    echo "2. Set environment variables:"
    echo "   export APP_STORE_CONNECT_USERNAME='your-apple-id'"
    echo "   export APP_STORE_CONNECT_PASSWORD='your-app-specific-password'"
    echo ""
    echo "BETA TESTER MANAGEMENT (Optional):"
    echo "1. Create a file called 'beta_testers.txt' in the project root"
    echo "2. Add email addresses, one per line"
    echo "3. The script will automatically invite them to TestFlight"
    echo ""
    echo "IMPORTANT: Update BUNDLE_ID in this script with your actual bundle identifier"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}🚀 TestFlight Deployment Script${NC}"
    echo -e "${BLUE}App: $APP_NAME${NC}"
    echo ""
    
    # Check requirements
    check_flutter_project
    check_xcode_tools
    
    # Show setup instructions if not configured
    if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ] && [ -z "$APP_STORE_CONNECT_USERNAME" ]; then
        print_setup_instructions
        read -p "Press Enter to continue with deployment (authentication will be checked later)..."
    fi
    
    # Ask for version bump
    ask_version_bump
    
    # Build process
    clean_build
    run_analysis
    build_ipa
    
    # Upload
    upload_testflight
    
    # Manage beta group assignment
    ask_beta_group_assignment
    
    echo ""
    print_success "🎉 Deployment completed successfully!"
    echo -e "${GREEN}Your app has been uploaded to TestFlight.${NC}"
    echo -e "${GREEN}It will be available for testing once Apple processes it (usually 10-90 minutes).${NC}"
}

# Show help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print_setup_instructions
    exit 0
fi

# Run main function
main