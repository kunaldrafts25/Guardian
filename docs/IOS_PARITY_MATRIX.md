# Guardian iOS vs. Android Parity Matrix

Guardian’s safety architecture relies heavily on OS-level permissions, background execution limitations, and hardware integrations. 

Because iOS strictly curtails background execution and hardware access compared to Android, several P0/P1 emergency features will **not function** on iOS without significant architectural compromises or reliance on the user keeping the app open.

## Feature Parity Matrix

| Feature | Android Status | iOS Status | Root Limitation |
|---------|---------------|------------|-----------------|
| **Shake to SOS (Background)** | ✅ Supported | ❌ Not Supported | iOS suspends accelerometer access when the app goes to the background. Requires the app to be active on screen. |
| **Fall Detection (Background)** | ✅ Supported | ❌ Not Supported | Same as Shake. Background accelerometer is strictly prohibited by iOS. |
| **Hardware Power Button Panic** | ✅ Supported | ❌ Not Supported | iOS does not allow intercepting power button clicks or volume button sequences for custom actions. |
| **Background Voice SOS** | ⚠️ Experimental | ❌ Not Supported | iOS suspends microphone access in the background unless the app is actively recording (which displays an orange dot and drains battery). |
| **Durable Native Cloud Outbox** | ✅ Supported (WorkManager) | ⚠️ Partial (BGTasks) | iOS `BGTaskScheduler` is strictly controlled by the OS and fires at OS discretion, unlike Android's reliable WorkManager. |
| **Check-in Expiration Backup** | ✅ Supported (AlarmManager) | ⚠️ Partial (Local Push) | Android can wake the app to fire a native emergency. iOS relies exclusively on server-side push notifications (which require network) or local notifications (which require the user to tap them). |
| **Direct SMS Dispatch** | ✅ Supported (SmsManager) | ❌ Not Supported | iOS completely sandboxes SMS. Apps can open the Messages composer (`MFMessageComposeViewController`), but the user *must* physically tap "Send". Background silent SMS is impossible. |
| **Live Location Streaming** | ✅ Supported (FGS) | ✅ Supported | Both support background location tracking, provided the correct permissions ("Always Allow") are granted. |

## Mitigation Strategy for iOS
To provide a viable safety product on iOS, the following workarounds are required:
1. **Critical Reliance on Cloud Agent**: Because iOS cannot send native SMS in the background or wake itself up to trigger a timeout, the **AWS Backend Timers** (EventBridge Schedulers) are the *only* guarantee of escalation for iOS users.
2. **Siri Shortcuts Integration**: Instead of hardware buttons, iOS users must be guided to set up a Siri Shortcut ("Hey Siri, trigger Guardian") or use the iOS 15+ Action Button on supported iPhones.
3. **Apple Watch Companion App**: To restore background Fall Detection and Heart Rate anomalies, a dedicated watchOS app must be developed to leverage Apple's native fall detection APIs and HealthKit.
