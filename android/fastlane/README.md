# Android Fastlane Setup

Fastlane configuration for deploying to Google Play Store.

## Prerequisites

### 1. Create Upload Keystore

If you don't have an upload keystore yet:

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 2. Configure key.properties

Copy the example file and fill in your values:

```bash
cp key.properties.example key.properties
```

Edit `key.properties` with your keystore credentials.

### 3. Google Play Service Account

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to **Settings > API access**
3. Click **Create new service account**
4. Follow the link to Google Cloud Console
5. Create a service account with **Editor** role
6. Create and download a JSON key
7. Save it as `android/fastlane/play-store-credentials.json`
8. Back in Play Console, grant the service account access to your app

### 4. First-time App Setup

Before Fastlane can upload, you must manually upload the first AAB:

1. Build the release AAB:
   ```bash
   flutter build appbundle --release
   ```

2. Go to Play Console > Your App > Internal testing
3. Create a new release and upload the AAB manually
4. Complete all required store listing information

## Usage

### Build and Deploy to Internal Testing

```bash
# Build the AAB
flutter build appbundle --release

# Deploy to internal testing track
cd android && bundle exec fastlane beta
```

### Promote to Beta Track

```bash
cd android && bundle exec fastlane promote_to_beta
```

## Lanes

| Lane | Description |
|------|-------------|
| `beta` | Upload to internal testing track |
| `beta_with_changelog` | Upload with version name |
| `promote_to_beta` | Promote internal to beta track |
