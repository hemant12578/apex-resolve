'use client';

import { useEffect } from 'react';
import { getApps, initializeApp } from 'firebase/app';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};

export default function FirebaseAnalytics() {
  useEffect(() => {
    if (!firebaseConfig.apiKey || !firebaseConfig.appId || !firebaseConfig.measurementId) return;
    const app = getApps()[0] ?? initializeApp(firebaseConfig);
    void import('firebase/analytics').then(async ({ getAnalytics, isSupported }) => {
      if (await isSupported()) getAnalytics(app);
    }).catch(() => {
      // Analytics availability varies with browser privacy settings.
    });
  }, []);

  return null;
}
