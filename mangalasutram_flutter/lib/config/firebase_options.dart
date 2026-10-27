import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Uses configuration parameters from google-services.json for project `mangalasutram-app`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATOqFbrNgPagdddvRfoYUzuHiUGcc4VNg',
    appId: '1:373832655262:android:f3a1858e4bb90bd33d768f',
    messagingSenderId: '373832655262',
    projectId: 'mangalasutram-app',
    storageBucket: 'mangalasutram-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyATOqFbrNgPagdddvRfoYUzuHiUGcc4VNg',
    appId: '1:373832655262:ios:placeholder',
    messagingSenderId: '373832655262',
    projectId: 'mangalasutram-app',
    storageBucket: 'mangalasutram-app.firebasestorage.app',
    iosBundleId: 'com.mangalasutram.mangalasutram',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyATOqFbrNgPagdddvRfoYUzuHiUGcc4VNg',
    appId: '1:373832655262:web:placeholder',
    messagingSenderId: '373832655262',
    projectId: 'mangalasutram-app',
    storageBucket: 'mangalasutram-app.firebasestorage.app',
  );
}
