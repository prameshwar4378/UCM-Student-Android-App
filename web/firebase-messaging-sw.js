importScripts('firebase-config.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

const config = self.firebaseConfig || {};

if (config.apiKey && config.appId && config.messagingSenderId && config.projectId) {
  firebase.initializeApp(config);

  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    const data = payload.data || {};
    const title = notification.title || data.title || 'Ultra Coach Matrix';
    const options = {
      body: notification.body || data.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data,
    };

    self.registration.showNotification(title, options);
  });
} else {
  console.warn('Firebase web messaging config is missing.');
}
