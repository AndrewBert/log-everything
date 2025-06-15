# TestFlight Automation Setup

This guide helps you set up automated TestFlight deployment for your Flutter app.

## Quick Start

1. **Make the script executable** (already done):
   ```bash
   chmod +x deploy_testflight.sh
   ```

2. **Configure authentication** (choose one method below)

3. **Update bundle ID** in `deploy_testflight.sh`:
   ```bash
   # Find your actual bundle ID in ios/Runner.xcodeproj/project.pbxproj
   # or in Xcode under Runner > General > Bundle Identifier
   BUNDLE_ID="your.actual.bundle.id"
   ```

4. **Run the script**:
   ```bash
   ./deploy_testflight.sh
   ```

## Authentication Setup

### Method 1: API Key (Recommended)

API keys are more secure and don't expire like passwords.

1. **Create API Key:**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Navigate to Users and Access > Keys
   - Click the "+" to create a new API key
   - Give it a name like "TestFlight Deployment"
   - Select "App Manager" role
   - Click "Generate"
   - **Download the .p8 file immediately** (you can only download it once)
   - Note the Key ID and Issuer ID

2. **Set Environment Variables:**
   Add these to your shell profile (`~/.zshrc` or `~/.bash_profile`):
   ```bash
   export APP_STORE_CONNECT_API_KEY_ID="ABCD123456"
   export APP_STORE_CONNECT_API_ISSUER_ID="12345678-1234-1234-1234-123456789012"
   export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_ABCD123456.p8"
   ```

3. **Reload your shell:**
   ```bash
   source ~/.zshrc  # or ~/.bash_profile
   ```

### Method 2: App-Specific Password

1. **Generate App-Specific Password:**
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Sign in with your Apple ID
   - Go to Security > App-Specific Passwords
   - Generate a new password for "TestFlight Deployment"

2. **Set Environment Variables:**
   ```bash
   export APP_STORE_CONNECT_USERNAME="your-apple-id@example.com"
   export APP_STORE_CONNECT_PASSWORD="your-app-specific-password"
   ```

## Script Features

- **Version Management**: Optionally bump version before deployment
- **Quality Checks**: Runs `flutter analyze` before building
- **Clean Build**: Automatically runs `flutter clean` and `flutter pub get`
- **Error Handling**: Stops on any error with clear messages
- **Progress Indicators**: Color-coded output shows progress
- **Flexible Authentication**: Supports both API keys and passwords

## Usage Examples

```bash
# Basic deployment
./deploy_testflight.sh

# Show help and setup instructions
./deploy_testflight.sh --help
```

## Troubleshooting

### "Bundle ID not found" error
Update the `BUNDLE_ID` variable in the script with your actual bundle identifier.

### "No authentication method configured" error
Set up one of the authentication methods above.

### "IPA file not found" error
The Flutter build failed. Check the build output for specific errors.

### "altool" deprecation warnings
Apple is transitioning to `notarytool`. The script uses `altool` which still works but may show deprecation warnings.

## Next Steps

Once set up, you can:
- Add this script to your CI/CD pipeline
- Create aliases for common deployment tasks
- Extend the script with additional features like Slack notifications

## Security Notes

- Never commit API keys or passwords to version control
- Store API key files in a secure location with restricted permissions
- Consider using a password manager for app-specific passwords
- Regularly rotate credentials for security