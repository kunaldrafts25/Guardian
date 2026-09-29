# Guardian AWS Deployment Runbook

Status: operator runbook. The canonical infrastructure is `aws/template.yaml`. The older partial `aws/setup_aws.py` provisioner has been removed.

## 1. Local prerequisites

- AWS CLI v2 installed and authenticated with an IAM deployment role or AWS IAM Identity Center session. Do not use root-account access keys or commit credentials to `.env`.
- AWS SAM CLI installed. On this workstation AWS CLI is present, but `sam` is currently missing.
- Choose one region. The current application default is `ap-south-1`.
- The deployment principal needs CloudFormation, IAM role creation, Lambda, API Gateway, DynamoDB, Cognito, EventBridge, Secrets Manager, SNS, S3 deployment-artifact, and Bedrock permissions.

Verify identity before deployment:

```powershell
aws sts get-caller-identity
aws configure get region
sam --version
```

## 2. Configure Firebase and Apple push credentials

Create one Firebase project and register:

- Android application ID: `com.company.guardian`
- iOS bundle ID: `com.company.guardian`

Record these non-secret mobile build values:

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_STORAGE_BUCKET` if used

For Android push, create an Amazon SNS FCM platform application using an FCM HTTP v1 service-account credential. Save its `PlatformApplicationArn` as the SAM parameter `FcmPlatformApplicationArn`.

For iOS:

1. Create an APNs authentication key in the Apple Developer account.
2. Upload that key to Firebase Cloud Messaging for the iOS app.
3. Create the appropriate SNS APNs platform application with the Apple key credentials.
4. Use APNS sandbox for development-device proof and APNS production for TestFlight/App Store builds. Save the production ARN as `ApnsPlatformApplicationArn` for production deployment.

Never commit FCM service-account JSON, APNs `.p8` files, Apple certificates, or private signing keys.

## 3. Configure identity, Google Maps Platform, and emergency SMS

### Identity

Guardian production login does not use SMS OTP. Configure a Google OAuth web
client for Cognito federation and deploy the stack with:

- `GoogleClientId`
- `GoogleClientSecret`
- `GuardianAuthCallbackUrl`
- `GuardianAuthLogoutUrl`

The mobile client uses Cognito managed login with authorization-code + PKCE.
Phone numbers remain emergency-contact data rather than account identifiers.

### Google Maps Platform

Create separate credentials with least privilege:

1. Android Maps SDK key restricted to package `com.company.guardian` and the
   production signing certificate fingerprint.
2. iOS Maps SDK key restricted to bundle `com.company.guardian`.
3. Server Places/Routes key restricted to only the required Google Maps Platform
   APIs and kept in AWS Secrets Manager.

Pass the server secret ARN as `GoogleMapsServerApiKeySecretArn`. Never compile
that server key into the mobile app.

### Emergency SMS

AWS SMS approval is independent of login. Android local emergency SMS may use the
device telephony API when permission and carrier service are available. Cloud
trusted-contact SMS remains an independent delivery channel and must not block
responder dispatch if unavailable.

Before arbitrary Indian recipients are enabled, complete the applicable AWS
End User Messaging/SNS production-access and DLT/template requirements. Treat
provider/OS acceptance separately from actual human receipt.

## 4. Enable the Bedrock model

- In Amazon Bedrock in the deployment region, open the model catalog and confirm that `anthropic.claude-3-haiku-20240307-v1:0` can be invoked.
- Complete Anthropic use-case/model terms if the account requests them.
- Set a conservative account budget and alarm.
- Keep deterministic policy authoritative. Bedrock is advisory and must never directly bypass tool authorization.

## 5. Build and deploy the SAM stack

From the repository:

```powershell
Set-Location D:\Guardian\aws
sam validate --lint --template-file template.yaml
sam build --template-file template.yaml
sam deploy --guided
```

Recommended first-deploy answers:

- Stack name: `guardian-mvp`
- Region: `ap-south-1`
- Confirm changes before deploy: yes
- Allow SAM CLI IAM role creation: yes
- Save arguments to `samconfig.toml`: yes, but review it before committing
- Parameter `FcmPlatformApplicationArn`: the real SNS FCM platform ARN
- Parameter `ApnsPlatformApplicationArn`: the real SNS APNs production ARN, or blank for an Android-only first staging deployment
- Parameter `GoogleClientId` / `GoogleClientSecret`: Google OAuth web client for Cognito
- Parameter `GoogleMapsServerApiKeySecretArn`: Secrets Manager ARN for Places/Routes
- Parameter `GuardianAuthCallbackUrl` / `GuardianAuthLogoutUrl`: registered mobile callbacks

The template provisions the authenticated API, agent and workflow-reconciler Lambdas, API Gateway, Cognito Google federation, responder group, DynamoDB safety tables, EventBridge/SQS workflow resources, generated policy-signing secret, and required IAM policies.

Read the deployed outputs:

```powershell
aws cloudformation describe-stacks `
  --stack-name guardian-mvp `
  --query "Stacks[0].Outputs" `
  --output table
```

Record `ApiEndpoint`, `CognitoUserPoolId`, `CognitoClientId`, and `CognitoAuthDomain`. The app communicates through `ApiEndpoint`; Cognito identifiers are server configuration generated by the stack.

## 6. Create the closed responder cohort

For the MVP, responders must be manually reviewed. After a responder has authenticated and the corresponding Cognito user exists:

```powershell
aws cognito-idp admin-add-user-to-group `
  --user-pool-id <CognitoUserPoolId> `
  --username <CognitoUsername> `
  --group-name responder
```

Create/update that responder's server profile with `verification_status=APPROVED`, a real trust score meeting policy, and current availability/location only after consent. Do not seed invented responders in the deployed table.

## 7. Build the connected mobile application

Supply configuration at build time; do not hard-code it:

```powershell
flutter build apk --release `
  --dart-define=AWS_API_ENDPOINT=<ApiEndpoint> `
  --dart-define=COGNITO_AUTH_DOMAIN=<CognitoAuthDomain> `
  --dart-define=COGNITO_CLIENT_ID=<CognitoClientId> `
  --dart-define=COGNITO_REDIRECT_URI=guardian://auth/callback `
  --dart-define=FIREBASE_API_KEY=<value> `
  --dart-define=FIREBASE_PROJECT_ID=<value> `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<value> `
  --dart-define=FIREBASE_ANDROID_APP_ID=<value> `
  --dart-define=FIREBASE_IOS_APP_ID=<value> `
  --dart-define=FIREBASE_IOS_BUNDLE_ID=com.company.guardian
```

Android release builds additionally require these environment variables:

- `GUARDIAN_KEYSTORE_PATH`
- `GUARDIAN_KEYSTORE_PASSWORD`
- `GUARDIAN_KEY_ALIAS`
- `GUARDIAN_KEY_PASSWORD`
- `GUARDIAN_GOOGLE_MAPS_ANDROID_API_KEY` (Android application-restricted Maps SDK key)

Use the Play upload key for distribution, not the temporary CI verification key.

For iOS, set `GOOGLE_MAPS_IOS_API_KEY` in the non-committed `ios/Runner/Config.xcconfig`, then run the equivalent archive on macOS with the Apple team, distribution profile, APNs entitlement, and the same Dart defines.

## 8. Staging acceptance test

Use two physical devices and real test phone numbers:

1. Protected user authenticates and completes readiness.
2. Responder authenticates, is manually approved, and registers a real push token.
3. Protected user sends the explicitly labelled contact test; verify provider acceptance and actual receipt separately.
4. Trigger a real controlled SOS payload.
5. Verify incident persistence, deterministic policy decision, and ledger evidence.
6. Verify only approved capped responders receive coarse invitations.
7. Accept on one responder device; verify exact location requires the bound grant.
8. Complete `EN_ROUTE -> ARRIVED -> COMPLETED`; confirm precise-location access is revoked.
9. Repeat for cancellation, expiry, no network, process death, locked device, reboot, token refresh, and disabled SNS endpoint.

## 9. Operational safeguards before wider use

- Add AWS Budgets and CloudWatch alarms for Lambda errors/throttles, API 5xx, DynamoDB throttles, Bedrock spend, and SMS spend.
- Enable API Gateway access logs with sensitive-field redaction and define log retention.
- Review least-privilege IAM; the MVP template intentionally has some wildcard permissions that should be narrowed to deployed model/platform resources.
- Enable CloudTrail and retain DynamoDB point-in-time recovery.
- Configure WAF/rate limits before public onboarding.
- Document data retention, incident deletion/export, responder suspension, abuse reports, and on-call ownership.
- Never market Guardian as guaranteed emergency-service dispatch. Provider acceptance and human receipt are different states.
