import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBLh1kz54d-85FzETal_pUp1hgizty_rFk',
    appId: '1:80836764748:web:6c76e96f665112ce49c0e9',
    messagingSenderId: '80836764748',
    projectId: 'puresip-purchasing',
    authDomain: 'puresip-purchasing.firebaseapp.com',
    storageBucket: 'puresip-purchasing.appspot.com',
    measurementId: '', // Optional
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBLh1kz54d-85FzETal_pUp1hgizty_rFk',
    appId: '1:80836764748:android:78cfe65bca6d363449c0e9',
    messagingSenderId: '80836764748',
    projectId: 'puresip-purchasing',
    storageBucket: 'puresip-purchasing.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBLh1kz54d-85FzETal_pUp1hgizty_rFk',
    appId: '1:80836764748:ios:9b72a97f887d353649c0e9',
    messagingSenderId: '80836764748',
    projectId: 'puresip-purchasing',
    storageBucket: 'puresip-purchasing.appspot.com',
    iosBundleId: 'com.puresip.purchasing',
  );
}
