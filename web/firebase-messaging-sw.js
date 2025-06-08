// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here. Other Firebase libraries
// are not available in the service worker.
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
firebase.initializeApp({
  apiKey: "AIzaSyBPw1Xn8WYZVSkHyHiUxx0R4KG-aWPcE4w",
  authDomain: "guardian-e787e.firebaseapp.com",
  projectId: "guardian-e787e",
  storageBucket: "guardian-e787e.firebasestorage.app",
  messagingSenderId: "989440136848",
  appId: "1:989440136848:web:e5c9a9e5c9a9e5c9a9e5c9",
  // Remove placeholder measurement ID
  // measurementId: "G-MEASUREMENT_ID"
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
