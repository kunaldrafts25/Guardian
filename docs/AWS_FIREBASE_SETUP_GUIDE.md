# Guardian Final AWS + Firebase Production Deployment Runbook

This runbook takes Guardian from a clean developer machine through staging validation and public Android/iOS production deployment. Staging is a mandatory release gate; production must use separate cloud resources, credentials, signing identities, monitoring, and data controls.

It is written for someone who is new to AWS and Firebase. Follow the sections in order.

## Public-release gates

The repository can be deployed for a controlled hackathon/pilot after this runbook's staging checks pass. Do **not** open an unrestricted public store rollout until all of these owner-controlled gates are complete:

- Production AWS, Firebase, SNS, SMS, Apple, and signing credentials are configured; none are committed to Git.
- The protected-user and approved-responder journey passes on physical Android and iOS devices under foreground, background, terminated, locked-screen, offline, and token-rotation conditions.
- Privacy policy, terms, support, retention, abuse-reporting, and account-deletion web pages are live at stable HTTPS URLs.
- An in-app account-deletion flow and backend erasure workflow are implemented and independently tested. The current repository does not yet provide self-service account deletion, so this is a public-store release blocker rather than a checkbox to bypass.
- Public responder discovery remains disabled. Only manually reviewed responders may be approved until identity review, reporting, suspension, appeal, and misuse-response operations exist.
- A named human is on call for the initial rollout and can halt distribution or disable backend actions if monitoring detects a safety regression.

## What Guardian uses

Guardian is **AWS-first**. Amazon SNS is the server-side push gateway: Android delivery uses Firebase Cloud Messaging (FCM), while iOS delivery uses Apple Push Notification service (APNs) directly.

```text
Flutter mobile app
  |
  | HTTPS API calls + Cognito access token + Guardian session
  v
Amazon API Gateway -> AWS Lambda
                         |
                         +-> Cognito: Google federation / token refresh
                         +-> DynamoDB: profiles, incidents, missions, audit data
                         +-> EventBridge: incident events
                         +-> Bedrock: advisory reasoning
                         +-> SNS: SMS and mobile push
                                      |
                                      +-> FCM for Android
                                      +-> APNs for iOS

Firebase is not the application database or authentication provider. On Android, Firebase supplies the FCM registration token that Guardian registers with SNS. On iOS, the Firebase Messaging SDK handles permission and notification integration, while Guardian registers the native APNs token with the matching SNS APNs application.
```

The infrastructure definition is [aws/template.yaml](../aws/template.yaml). The existing Flutter CI workflow tests and builds the project, but it does not deploy AWS resources automatically.

## Important safety rules

- Start with a **staging** AWS stack and test phone numbers.
- Do not use the AWS root account for daily work.
- Never commit AWS access keys, Firebase service-account JSON, APNs `.p8` files, Apple certificates, keystores, passwords, or production tokens.
- Do not put secrets in Dart source code or in `--dart-define` values committed to GitHub.
- Do not test with real emergency recipients until delivery behavior is verified.
- AWS SMS sandbox permits only verified test numbers. Production SMS access is a separate AWS approval.

## 1. Install the local tools

Open PowerShell as a normal user.

Install the required tools:

```powershell
winget install Amazon.AWSCLI
winget install Amazon.SAM-CLI
winget install Python.Python.3.12
```

Flutter and Android Studio are also required to build the mobile application. Install them using the official Flutter and Android Studio installers if they are not already installed.

Close and reopen PowerShell, then verify:

```powershell
aws --version
sam --version
python --version
flutter --version
```

If `sam --version` fails, AWS SAM CLI is not installed correctly yet. Do not continue to deployment until it works.

Optional but recommended for SAM builds:

- Install Docker Desktop.
- Start Docker Desktop before running `sam build` if SAM asks for a container build.

## 2. Create and secure the AWS account

In the AWS Console:

1. Create or sign in to the AWS account.
2. Add billing information.
3. Enable MFA on the root user.
4. Do not create root access keys.
5. Select `ap-south-1` as the first deployment region.
6. Create an AWS Budget with a small monthly amount.

For a beginner staging setup, IAM Identity Center is easier than creating long-lived access keys:

1. Search for **IAM Identity Center** in the AWS Console.
2. Enable it.
3. Create a user for yourself.
4. Create a permission set. `AdministratorAccess` is acceptable for initial staging only.
5. Assign the user to the AWS account.
6. Record the IAM Identity Center start URL and region.

For production, replace broad administrator access with a restricted deployment role. The deployment needs CloudFormation, IAM role creation, Lambda, API Gateway, DynamoDB, Cognito, EventBridge, Secrets Manager, SNS, S3 deployment artifacts, CloudWatch, and Bedrock permissions.

## 3. Log in from Windows

Configure an IAM Identity Center profile:

```powershell
aws configure sso
```

Use the start URL, account, permission set, and region shown in IAM Identity Center. Choose a profile name such as `guardian`.

Log in and select the profile for this PowerShell session:

```powershell
aws sso login --profile guardian
$env:AWS_PROFILE = "guardian"
$env:AWS_DEFAULT_REGION = "ap-south-1"
```

Verify that the CLI is using the intended account:

```powershell
aws sts get-caller-identity
aws configure get region
```

The returned account ID must be your intended staging account. If it is wrong, stop and fix the AWS profile before deploying.

## 4. Create the Firebase project

Open the Firebase Console and create a project, for example:

```text
Project name: Guardian Staging
Project ID: choose a unique ID
```

Google Analytics is optional for this project. It is not required for the AWS backend or push notifications.

### Register the Android app

In the Firebase project:

1. Select **Add app** and choose Android.
2. Use this exact package name:

```text
com.company.guardian
```

3. Download `google-services.json`.
4. Keep the file outside Git. This repository ignores `android/app/google-services.json`.
5. Place it at `android/app/google-services.json` for local Android builds. Gradle applies the Google Services plug-in only when a real config file exists, so CI can continue using Dart defines without a fabricated file.

The package name must match `applicationId` in [android/app/build.gradle](../android/app/build.gradle).

### Record Firebase mobile values

From Firebase project settings, record these values:

```text
FIREBASE_API_KEY
FIREBASE_PROJECT_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_ANDROID_APP_ID
FIREBASE_STORAGE_BUCKET       (optional; use it if Firebase supplies one)
```

For Android, the values come from the Firebase web/app configuration. Do not confuse the Firebase project ID with the AWS account ID.

### Register the iOS app

For iOS, add another Firebase app with this exact bundle ID:

```text
com.company.guardian
```

Record:

```text
FIREBASE_IOS_APP_ID
FIREBASE_IOS_BUNDLE_ID=com.company.guardian
```

The iOS build and Apple signing steps require macOS and Xcode. Register the iOS app before creating production APNs and SNS resources.

## 5. Create Firebase FCM credentials for Amazon SNS

Amazon SNS needs permission to send through FCM. Use the modern FCM HTTP v1 credential flow.

In Firebase:

1. Open **Project settings**.
2. Open the **Service accounts** tab.
3. Create or select a service account with permission to send Firebase Cloud Messaging messages.
4. Generate a private key JSON file.
5. Download it once.
6. Store it outside the repository, for example in a protected password-manager folder.

Do not rename it into the project, commit it, or paste its contents into source files.

In AWS:

1. Open **Amazon SNS** in `ap-south-1`.
2. Open **Mobile > Push notifications**.
3. Create a platform application for Android/FCM.
4. Select the FCM HTTP v1 credential option if shown.
5. Upload or paste the Firebase service-account credential as requested by the AWS Console.
6. Name it something such as `guardian-staging-android`.
7. Create the platform application.
8. Copy its `PlatformApplicationArn`.

The ARN looks similar to:

```text
arn:aws:sns:ap-south-1:123456789012:app/GCM/guardian-staging-android
```

This ARN is not a private key, but keep it associated with the correct staging stack. You will pass it to SAM as `FcmPlatformApplicationArn`.

## 6. Configure iOS push

Do this only when building iOS:

1. Create an APNs authentication key in the Apple Developer portal and record its Key ID and Apple Team ID.
2. Upload the APNs `.p8` key to the iOS app in Firebase Cloud Messaging. Guardian uses the Firebase Messaging SDK on-device, so its Apple integration must remain correctly configured.
3. In AWS SNS, create an **Apple development** (`APNS_SANDBOX`) platform application for the staging stack. Choose token-based authentication and supply the APNs `.p8` key, Key ID, Team ID, and bundle ID requested by SNS.
4. Create a separate **Apple production** (`APNS`) platform application for TestFlight and App Store builds, using the same APNs token credentials where appropriate.
5. Copy the sandbox `PlatformApplicationArn` into the staging SAM deployment and the production ARN into the production SAM deployment. Do not mix sandbox device tokens with the production application or production tokens with the sandbox application.

Never commit the Apple `.p8` key, certificate, or private signing material.

## 7. Configure Cognito Google federation and emergency SMS

Guardian production authentication does not use SMS OTP. Cognito federates Google identity using authorization-code + PKCE. AWS SMS remains an independent emergency-contact delivery channel.

In AWS Console:

1. Open **End User Messaging SMS** or the SMS settings available through SNS.
2. Select `ap-south-1`.
3. Check whether the account is in the SMS sandbox.
4. Add your own test phone number as an approved destination.
5. Add every controlled test number you will use.
6. Set an SMS spending limit.
7. Enable delivery and failure logging.

While AWS messaging remains sandboxed/restricted, cloud trusted-contact SMS may work only for approved or verified destinations. This does not block Google/Cognito login. Request production messaging access only for the emergency-contact SMS channel.

For Indian recipients, complete the required DLT entity/template registration and use approved transactional templates. An unregistered sender or template may be rejected by carriers.

## 8. Enable Amazon Bedrock

In the AWS Console:

1. Switch to `ap-south-1`.
2. Open **Amazon Bedrock**.
3. Open the model access or model catalog page.
4. Confirm access to:

```text
anthropic.claude-3-haiku-20240307-v1:0
```

5. Accept Anthropic terms if AWS requests them.
6. Create a budget alarm for Bedrock usage.

The model is an advisory component. Guardian's deterministic policy remains responsible for mandatory safety actions.

## 9. Understand the repository configuration

There are three different configuration locations. Do not mix them up.

### A. AWS backend configuration

You normally do not edit these values manually. [aws/template.yaml](../aws/template.yaml) injects them into Lambda:

```text
COGNITO_USER_POOL_ID
COGNITO_CLIENT_ID
DYNAMODB_* table names
AGENT_POLICY_SECRET_ARN
EVENTBUS_NAME
SNS_FCM_PLATFORM_ARN
SNS_APNS_PLATFORM_ARN
BEDROCK_MODEL_ID
```

CloudFormation fills in Cognito IDs, table names, and the generated Secrets Manager ARN during deployment.

### B. Flutter mobile build configuration

The Flutter app reads build-time values using `String.fromEnvironment` in:

- [lib/core/services/aws_auth_service.dart](../lib/core/services/aws_auth_service.dart)
- [lib/core/services/aws_incident_service.dart](../lib/core/services/aws_incident_service.dart)
- [lib/core/services/firebase_runtime_options.dart](../lib/core/services/firebase_runtime_options.dart)

The mobile values can be passed with `--dart-define`. Android also supports the native `android/app/google-services.json` configuration. There is no supported `.env` loader in this app.

Required Android staging defines:

```text
AWS_API_ENDPOINT
FIREBASE_API_KEY
FIREBASE_PROJECT_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_ANDROID_APP_ID
```

Optional:

```text
FIREBASE_STORAGE_BUCKET
```

Required iOS defines:

```text
AWS_API_ENDPOINT
FIREBASE_API_KEY
FIREBASE_PROJECT_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_IOS_APP_ID
FIREBASE_IOS_BUNDLE_ID
```

The release app requires `AWS_API_ENDPOINT` and requires it to use HTTPS.

### C. Android release signing configuration

The Gradle file reads these environment variables:

```text
GUARDIAN_KEYSTORE_PATH
GUARDIAN_KEYSTORE_PASSWORD
GUARDIAN_KEY_ALIAS
GUARDIAN_KEY_PASSWORD
```

These are unrelated to AWS and Firebase. They sign the Android release package. Never commit a keystore or passwords.

## 10. Validate the repository before deployment

From PowerShell:

```powershell
Set-Location D:\Guardian
flutter pub get
flutter analyze
flutter test
python -m pytest aws/tests -q
```

Validate the SAM template:

```powershell
Set-Location D:\Guardian\aws
sam validate --lint --template-file template.yaml
```

Build the backend package:

```powershell
sam build --template-file template.yaml
```

If any of these fail, fix the local problem before creating AWS resources.

## 11. Deploy the staging AWS stack

Stay in `D:\Guardian\aws` and run:

```powershell
sam deploy --guided --region ap-south-1
```

Use these first-deployment answers:

```text
Stack name: guardian-staging
AWS Region: ap-south-1
Confirm changes before deploy: Y
Allow SAM CLI IAM role creation: Y
Save arguments to samconfig.toml: Y
```

When SAM asks for parameters:

```text
EnvironmentName: staging
FcmPlatformApplicationArn: paste the Android SNS platform ARN
ApnsPlatformApplicationArn: paste the APNS_SANDBOX ARN, or leave blank for Android-only staging
```

SAM creates these AWS resources from [aws/template.yaml](../aws/template.yaml):

- API Gateway
- Guardian API Lambda
- Guardian agent Lambda
- Cognito User Pool and app client
- Cognito responder group
- DynamoDB incident, user, session, mission, responder, event, throttle, ledger, and authorization tables
- EventBridge incident rule
- Secrets Manager policy-signing secret
- Lambda execution roles and permissions

The first deployment can take several minutes.

The generated `samconfig.toml` stores deployment settings. Review it before committing. It may contain stack and parameter values, but never place passwords or private keys in it.

## 12. Read the deployed outputs

Run:

```powershell
aws cloudformation describe-stacks `
  --stack-name guardian-staging `
  --region ap-south-1 `
  --query "Stacks[0].Outputs" `
  --output table
```

Copy these outputs:

```text
ApiEndpoint
CognitoUserPoolId
CognitoClientId
```

The mobile build needs `ApiEndpoint`, `CognitoAuthDomain`, and `CognitoClientId` from the deployed stack outputs. The backend receives the user-pool/table configuration through CloudFormation environment variables.

You can also inspect the stack status:

```powershell
aws cloudformation describe-stacks `
  --stack-name guardian-staging `
  --region ap-south-1 `
  --query "Stacks[0].StackStatus" `
  --output text
```

A successful deployment ends in `CREATE_COMPLETE` or, on an update, `UPDATE_COMPLETE`.

## 13. Build Android with AWS and Firebase values

From the repository root:

```powershell
Set-Location D:\Guardian
```

For a debug build on a connected device:

```powershell
flutter run `
  --dart-define=AWS_API_ENDPOINT=https://YOUR_API_ENDPOINT `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_FIREBASE_ANDROID_APP_ID `
  --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_FIREBASE_STORAGE_BUCKET
```

For a release APK, use the same defines:

```powershell
flutter build apk --release `
  --dart-define=AWS_API_ENDPOINT=https://YOUR_API_ENDPOINT `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_FIREBASE_ANDROID_APP_ID `
  --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_FIREBASE_STORAGE_BUCKET
```

Do not literally use `YOUR_API_ENDPOINT`. Replace every placeholder with the value from Firebase or CloudFormation.

For development, omitting `AWS_API_ENDPOINT` allows the app's local fallback URL. For release builds, the app intentionally fails if the endpoint is missing or not HTTPS.

## 14. Configure Android release signing

Create a real release/upload keystore once and store it outside the repository. Use a password manager for the passwords.

Set the variables only in the current PowerShell session:

```powershell
$env:GUARDIAN_KEYSTORE_PATH = "C:\secure\guardian-upload.jks"
$env:GUARDIAN_KEYSTORE_PASSWORD = "your-keystore-password"
$env:GUARDIAN_KEY_ALIAS = "guardian-upload"
$env:GUARDIAN_KEY_PASSWORD = "your-key-password"
```

Then build:

```powershell
flutter build appbundle --release `
  --dart-define=AWS_API_ENDPOINT=https://YOUR_API_ENDPOINT `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_FIREBASE_ANDROID_APP_ID
```

Use the Play upload key for Google Play distribution. The temporary CI key is only for build verification and must not be used to publish the app.

### Publish Android through controlled tracks

1. Create the app in Google Play Console with package name `com.company.guardian`.
2. Enrol in Play App Signing and keep the upload keystore and recovery material outside Git.
3. Complete App access, Ads, Content rating, Target audience, Data safety, privacy-policy, account-deletion, and sensitive-permission declarations using the behavior of the exact release being uploaded.
4. Create an **Internal testing** release and upload `build/app/outputs/bundle/release/app-release.aab`.
5. Add only controlled testers. Install from Play, then repeat the complete staging checklist on a physical Android device, including locked-screen, force-stop/reopen, background location, notification permission, SMS, and token refresh.
6. Promote the same accepted artifact through any required closed test, then to production. Start with the smallest practical staged rollout rather than 100%.
7. Watch crash/ANR reports, CloudWatch alarms, failed SNS endpoints, Cognito/session failures, incident creation, and contact-delivery evidence during rollout. Halt the rollout if the safety journey regresses.

Never upload the CI artifact: its certificate is deliberately ephemeral and is not a distribution identity.

## 14A. Configure, archive, and distribute iOS

Use a macOS machine with the same Flutter version pinned in CI, Xcode, CocoaPods, and an Apple Developer team membership.

### Apple and Firebase configuration

1. In Apple Developer, create or confirm the explicit App ID `com.company.guardian`.
2. Enable Push Notifications for the App ID.
3. Create an APNs token key. Record the Key ID and Team ID and store the downloaded `.p8` file in a secret manager; Apple only allows one download.
4. In Firebase, open the iOS app's Cloud Messaging settings and upload the APNs key.
5. In Xcode, open `ios/Runner.xcworkspace`, select the Runner target, choose the production Team, and confirm the bundle ID is `com.company.guardian`.
6. Confirm Signing & Capabilities contains Push Notifications. The repository's `Runner.entitlements` already maps Debug to APNs development and Profile/Release to APNs production.
7. In SNS, create separate APNS_SANDBOX and APNS production platform applications when both development-device and TestFlight/App Store testing are required.
8. Pass the production APNS platform application ARN to the production SAM stack as `ApnsPlatformApplicationArn`.

Guardian registers the native APNs device token with the SNS APNs platform application. Do not register an FCM registration token against the APNs application.

### Verify the unsigned simulator build

From the repository root on macOS:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator --no-codesign
```

This must pass before using a distribution certificate. It proves dependency integration but not APNs, signing, background delivery, or a physical-device archive.

### Build the signed archive

Use production values and the Release configuration:

```bash
flutter build ipa --release \
  --dart-define=AWS_API_ENDPOINT=https://YOUR_API_ENDPOINT \
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_MESSAGING_SENDER_ID \
  --dart-define=FIREBASE_IOS_APP_ID=YOUR_FIREBASE_IOS_APP_ID \
  --dart-define=FIREBASE_IOS_BUNDLE_ID=com.company.guardian \
  --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_FIREBASE_STORAGE_BUCKET
```

If automatic signing is unavailable, open `ios/Runner.xcworkspace`, select **Any iOS Device**, then use **Product > Archive**. Validate the archive in Organizer before upload.

Upload to TestFlight first. On a physical iPhone, verify notification permission, APNs token registration, SNS endpoint creation, foreground/background/terminated notification handling, authenticated notification routing, and precise-location revocation. Only submit for App Review after those checks pass.

In App Store Connect, create the app record for bundle ID `com.company.guardian`, upload the archive, complete export-compliance and privacy answers, attach the tested build to an internal TestFlight group, and only then submit that same accepted build for review. Use phased release and monitor the same backend delivery and incident alarms as Android.

### Apple privacy and review evidence

Before App Store submission:

- Complete App Privacy answers using the actual data collected by this release.
- Provide location, notification, microphone, speech, and emergency-contact purpose descriptions that match real behavior.
- Explain background location and emergency use without promising unsupported side-button interception on iOS.
- Provide a review account or documented federated-login review path. For iOS distribution, confirm the final App Store login configuration satisfies Apple's login-services requirements.
- Include responder safety, reporting, and contact details in review notes.
- Publish privacy policy, terms, data-retention policy, and account-deletion instructions at stable HTTPS URLs.

## 15. Test the complete staging flow

Use two physical Android devices and only controlled test phone numbers.

### Authentication

1. Install the staging APK.
2. Enter a verified test phone number.
3. Confirm that Google -> Cognito managed login completes and a Guardian device session is issued.
4. Complete login.
5. Close and reopen the app.
6. Confirm that the secure session is restored.
7. Sign out and confirm that protected API requests stop working.

### Push registration

1. Allow notification permission.
2. On Android, confirm the app obtains an FCM registration token. On iOS, confirm it obtains a native APNs token.
3. Confirm the app calls the Guardian device registration endpoint with the correct `android` or `ios` platform value.
4. Confirm an endpoint is created under the matching SNS platform application.
5. Send a controlled push notification and confirm foreground, background, terminated, and notification-tap behavior on a physical device.

The app's push flow is implemented in [lib/core/services/aws_sns_service.dart](../lib/core/services/aws_sns_service.dart). The Guardian backend registers an Android FCM token or iOS APNs token with the corresponding SNS platform application. An iOS simulator cannot prove APNs delivery.

### Incident flow

1. Configure one real test trusted contact.
2. Use the explicitly labelled contact test first.
3. Trigger one controlled SOS.
4. Confirm one incident appears in DynamoDB.
5. Confirm an EventBridge event invokes the agent Lambda.
6. Confirm delivery evidence distinguishes accepted, delivered, failed, or unknown.
7. Confirm Bedrock failure does not prevent the mandatory deterministic safety action.
8. Confirm only approved responders receive coarse invitations.
9. Confirm precise location requires a valid mission grant.
10. Complete `EN_ROUTE`, `ARRIVED`, and `COMPLETED`.
11. Confirm precise-location access is revoked after completion.

Repeat tests for cancellation, expiry, no network, locked screen, process death, reboot, token refresh, and a disabled SNS endpoint.

## 16. Approve a staging responder

A responder must exist in Cognito before adding the responder group:

```powershell
aws cognito-idp admin-add-user-to-group `
  --user-pool-id YOUR_COGNITO_USER_POOL_ID `
  --username YOUR_COGNITO_USERNAME `
  --group-name responder `
  --region ap-south-1
```

The responder's server profile must be manually reviewed and contain real, consented values such as:

```text
verification_status=APPROVED
trust score meeting policy
availability=true only when the user consents
current location only when the user consents
```

Do not seed invented responders in DynamoDB.

## 17. Production is a separate deployment

Do not reuse the staging stack for public users.

Create a separate production stack:

```text
Stack name: guardian-production
```

Use separate:

- AWS account where practical, and always a separate stack and data resources
- Firebase project or clearly separated production app configuration
- SNS FCM/APNs platform applications
- verified test and production phone-number process
- Android signing key
- budgets and alarms
- CloudWatch log groups and retention policy
- responder approval process

The template prefixes named Cognito and DynamoDB resources with `EnvironmentName`, so staging and production cannot share data accidentally. For a new production deployment, use `EnvironmentName=production`. If an older stack was deployed before this parameter existed, review the CloudFormation change set carefully because renaming a stateful resource requires replacement; do not update a data-bearing stack blindly.

Deploy production only after staging acceptance tests pass:

```powershell
sam deploy --config-env production --region ap-south-1
```

Only use this command after creating and reviewing a production `samconfig.toml` environment containing `EnvironmentName=production` and the production SNS ARNs. Require a human approval step in CI/CD.

## 18. Optional GitHub Actions automation

The existing [`.github/workflows/flutter_ci.yml`](../.github/workflows/flutter_ci.yml) already runs Flutter tests, backend tests, SAM validation, SAM build, and mobile build checks.

It currently does **not** deploy AWS. To automate deployment later:

1. Create a GitHub Actions OIDC identity provider in AWS.
2. Create a deployment role that trusts only your repository and selected branches/environments.
3. Add GitHub Environments named `staging` and `production`.
4. Require approval for the production environment.
5. Store non-secret configuration as GitHub environment variables:

```text
AWS_REGION
FcmPlatformApplicationArn
ApnsPlatformApplicationArn
AWS_API_ENDPOINT
FIREBASE_API_KEY
FIREBASE_PROJECT_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_ANDROID_APP_ID
```

6. Store private signing material only as protected secrets or use a secure signing service.
7. Run tests before `sam deploy`.
8. Deploy staging automatically after merge.
9. Run smoke tests.
10. Deploy production only after approval.

Do not put permanent `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` values in GitHub. OIDC should issue short-lived AWS credentials.

## 19. Files you may change

Normal deployment should not require application-code changes.

You may create or update:

```text
samconfig.toml                  generated by SAM; review before committing
android/app/google-services.json local Firebase Android file; ignored by Git
```

You may use local-only files outside the repository for:

```text
Firebase service-account JSON
APNs .p8 key
Android keystore
AWS credential cache
```

You may pass mobile values at build time with `--dart-define`.

Do not manually edit generated build output under `build/` or `.aws-sam/`.

Do not put AWS table names or secrets into Flutter source. Supply the public API endpoint, Cognito managed-login domain, and public Cognito mobile client ID as build-time values.

## 20. Files you should not modify for normal setup

Do not change these just to add environment values:

- [lib/main.dart](../lib/main.dart)
- [lib/core/services/firebase_runtime_options.dart](../lib/core/services/firebase_runtime_options.dart)
- [lib/core/services/aws_auth_service.dart](../lib/core/services/aws_auth_service.dart)
- [lib/core/services/aws_sns_service.dart](../lib/core/services/aws_sns_service.dart)
- [aws/template.yaml](../aws/template.yaml)

Change code only when a test or a real deployment error proves that the implementation needs a change.

## 21. What belongs in `.env`

The current Flutter and SAM deployment paths do not read a project `.env` file. Do not assume creating `.env` will configure the app.

For local convenience, you can keep a private PowerShell script outside Git, such as:

```text
C:\secure\guardian-staging-env.ps1
```

Example contents:

```powershell
$env:AWS_PROFILE = "guardian"
$env:AWS_DEFAULT_REGION = "ap-south-1"
$env:GUARDIAN_KEYSTORE_PATH = "C:\secure\guardian-upload.jks"
$env:GUARDIAN_KEYSTORE_PASSWORD = "..."
$env:GUARDIAN_KEY_ALIAS = "guardian-upload"
$env:GUARDIAN_KEY_PASSWORD = "..."
```

Do not put Dart defines containing private keys in this file. Firebase API keys are normally client configuration values, but still keep environment-specific values organized and do not commit credentials or service-account files.

Run the script in a private PowerShell session only, then pass the Dart defines explicitly to Flutter.

## 22. Common problems

### `sam` is not recognized

Install AWS SAM CLI, reopen PowerShell, and run:

```powershell
sam --version
```

### `Unable to locate credentials`

Log in again:

```powershell
aws sso login --profile guardian
$env:AWS_PROFILE = "guardian"
aws sts get-caller-identity
```

### Google/Cognito sign-in does not complete

Check that:

- the deployed user-pool client lists Google as a supported identity provider;
- the Google OAuth web client ID/secret used by Cognito are correct;
- the Google OAuth redirect configuration allows Cognito's provider redirect;
- the Cognito app client callback URL exactly matches `guardian://auth/callback`;
- the mobile build received `COGNITO_AUTH_DOMAIN`, `COGNITO_CLIENT_ID`, and `COGNITO_REDIRECT_URI`;
- the Android/iOS custom URL scheme is registered and returns the authorization code to Guardian;
- the access token includes `aws.cognito.signin.user.admin`, which Guardian uses to bootstrap the device session;
- the Guardian API can validate the Cognito access token and refresh-token ownership.

AWS SMS sandbox/DLT configuration is unrelated to Guardian login and should be debugged only for the separate emergency-contact SMS channel.

### `AWS_API_ENDPOINT is required in release builds`

Add the API endpoint to the release command:

```text
--dart-define=AWS_API_ENDPOINT=https://...
```

### Push token is missing

Check that:

- Firebase values were passed with `--dart-define`.
- Android package name is `com.company.guardian`.
- Notification permission was granted.
- The FCM service-account credential was configured in SNS.
- The SNS platform application ARN was passed to SAM.
- The device has Google Play services where required.

### Push token exists but notification is not received

Check the SNS platform application, endpoint status, CloudWatch/Lambda logs, FCM credential validity, and whether the endpoint was disabled after a prior failure.

### Bedrock invocation is denied

Check model access, the region, the Lambda execution role, the model ID, and the Bedrock service quotas.

### Release build fails because signing is missing

Set all four `GUARDIAN_*` signing variables before running a release build. A debug build does not prove that production signing is configured.

### CloudFormation rollback

Inspect the failed stack events:

```powershell
aws cloudformation describe-stack-events `
  --stack-name guardian-staging `
  --region ap-south-1 `
  --max-items 20 `
  --output table
```

Fix the first failure, then run `sam deploy` again. Do not delete retained production tables to solve an unrelated deployment error.

## 23. Cost and cleanup

The staging stack uses pay-per-request DynamoDB tables, but AWS services can still incur charges for SMS, Bedrock, logs, data transfer, and other usage.

Monitor:

- AWS Budgets
- SNS SMS spend
- Bedrock usage
- Lambda invocations
- CloudWatch logs
- API Gateway requests

To remove a disposable staging stack after testing:

```powershell
aws cloudformation delete-stack `
  --stack-name guardian-staging `
  --region ap-south-1
```

The template retains several safety data tables by design. Confirm what will remain before deleting a stack. Never run delete commands against production unless the data-retention decision is explicit and approved.

## 24. Short checklist

Before deployment:

- [ ] AWS CLI installed
- [ ] SAM CLI installed
- [ ] AWS SSO login works
- [ ] Correct AWS account and region verified
- [ ] Firebase Android app uses `com.company.guardian`
- [ ] Firebase iOS app and Apple App ID use `com.company.guardian`
- [ ] Firebase values recorded
- [ ] FCM service-account credential configured in SNS
- [ ] Android SNS platform ARN copied
- [ ] APNS_SANDBOX and APNS production credentials/ARNs separated
- [ ] SMS test number verified
- [ ] Bedrock model access enabled
- [ ] Flutter tests pass
- [ ] Python tests pass
- [ ] SAM validation passes

After deployment:

- [ ] CloudFormation stack is complete
- [ ] Stack uses the intended `EnvironmentName`
- [ ] API endpoint copied
- [ ] Android App Bundle includes production AWS/Firebase Dart defines and release signing
- [ ] iOS archive includes production AWS/Firebase Dart defines and App Store signing
- [ ] Google/Cognito federated login tested
- [ ] SNS push tested on physical Android and iOS devices in every app state
- [ ] Controlled SOS tested
- [ ] DynamoDB incident persistence verified
- [ ] EventBridge and agent invocation verified
- [ ] No-network and locked-device behavior tested
- [ ] Budgets and monitoring configured
- [ ] Privacy policy, terms, support, retention, and account-deletion pages are live
- [ ] Play internal testing and TestFlight acceptance tests passed
- [ ] Store declarations and reviewer instructions match the shipped behavior

The first practical path is: configure Firebase and both push platforms -> verify an SMS sandbox number -> enable Bedrock -> deploy an isolated staging stack -> copy `ApiEndpoint` -> build both staging apps -> test with physical devices -> deploy an isolated production stack -> run store pre-release tests -> release gradually while watching alarms.

## 25. Authoritative references

Use these vendor documents when a console label changes:

- [AWS: create an SNS mobile platform application](https://docs.aws.amazon.com/sns/latest/dg/mobile-push-send-register.html)
- [AWS: configure FCM HTTP v1 credentials for SNS](https://docs.aws.amazon.com/sns/latest/dg/sns-fcm-authentication-methods.html)
- [AWS: manage SNS device-token endpoints](https://docs.aws.amazon.com/sns/latest/dg/mobile-platform-endpoint.html)
- [Firebase: configure Cloud Messaging for Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Flutter: build and release Android](https://docs.flutter.dev/deployment/android)
- [Flutter: build and release iOS](https://docs.flutter.dev/deployment/ios)
