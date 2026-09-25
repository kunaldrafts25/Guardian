# Guardian iOS vs. Android Parity Matrix

Guardian’s safety architecture relies heavily on OS-level permissions, background execution limitations, and hardware integrations. 

Because iOS strictly curtails background execution and hardware access compared to Android, several P0/P1 emergency features will **not function** on iOS without significant architectural compromises or reliance on the user keeping the app open.

## Feature Parity Matrix

| Feature | Android Status | iOS Status | Root Limitation |
|---------|---------------|------------|-----------------|
| **Shake to SOS (Background)** | ✅ Supported | ❌ Not Supported | iOS suspends accelerometer access when the app goes to the background. Requires the app to be active on screen. |
| **Fall Detection (Background)** | ✅ Supported | ❌ Not Supported | Same as Shake. Background accelerometer is strictly prohibited by iOS. |
| **Hardware Power Button Panic** | ✅ Supported | ❌ Not Supported | iOS does not allow intercepting power button clicks or volume button sequences for custom actions. |
| **Background Voice SOS** | ⚠️ Code-only / not product-wired | ❌ Not Implemented | Android voice helpers exist but are not an active, background-qualified product trigger. iOS background microphone restrictions make equivalent always-listening behavior inappropriate. |
| **Durable Native Cloud Outbox** | ✅ Implemented (WorkManager) | ❌ Not Implemented | Android uses an account-bound encrypted native outbox. No equivalent iOS BGTask implementation is currently present in this repository. |
| **Check-in Expiration Backup** | ✅ Supported (AlarmManager) | ⚠️ Partial (Local Push) | Android can wake the app to fire a native emergency. iOS relies exclusively on server-side push notifications (which require network) or local notifications (which require the user to tap them). |
| **Direct SMS Dispatch** | ✅ Supported (SmsManager) | ❌ Not Supported | iOS completely sandboxes SMS. Apps can open the Messages composer (`MFMessageComposeViewController`), but the user *must* physically tap "Send". Background silent SMS is impossible. |
| **Live Location Streaming** | ✅ Supported (FGS) | ✅ Supported | Both support background location tracking, provided the correct permissions ("Always Allow") are granted. |

## Mitigation Strategy for iOS
To provide a viable safety product on iOS, the following workarounds are required:
1. **Cloud-backed escalation after incident ingestion**: Once an iOS incident reaches the backend, EventBridge Scheduler owns verification/escalation deadlines. This does not guarantee that a terminated/offline iOS app can create the incident in the first place.
2. **Siri Shortcuts Integration**: Instead of hardware buttons, iOS users must be guided to set up a Siri Shortcut ("Hey Siri, trigger Guardian") or use the iOS 15+ Action Button on supported iPhones.
3. **Apple Watch Companion App**: To restore background Fall Detection and Heart Rate anomalies, a dedicated watchOS app must be developed to leverage Apple's native fall detection APIs and HealthKit.
