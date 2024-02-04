// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAKdyB8vmltpjLiMlJ8XvCGd8EldsLsSsY',
    appId: '1:858453983778:web:069306e8316624134e807b',
    messagingSenderId: '858453983778',
    projectId: 'the-crane-e2ff1',
    authDomain: 'the-crane-e2ff1.firebaseapp.com',
    storageBucket: 'the-crane-e2ff1.appspot.com',
    measurementId: 'G-TPC6VMS2E6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCp-3Xs6_D49hZCCJLLAjCn0CQd-zDdJWQ',
    appId: '1:858453983778:android:e0dbe6ea1e4d1e974e807b',
    messagingSenderId: '858453983778',
    projectId: 'the-crane-e2ff1',
    storageBucket: 'the-crane-e2ff1.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAznOIa0GvLBNbSny_VMkrGgukTZ5tdYTA',
    appId: '1:858453983778:ios:8b631a0e33c972ba4e807b',
    messagingSenderId: '858453983778',
    projectId: 'the-crane-e2ff1',
    storageBucket: 'the-crane-e2ff1.appspot.com',
    iosBundleId: 'com.example.theCrane',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAznOIa0GvLBNbSny_VMkrGgukTZ5tdYTA',
    appId: '1:858453983778:ios:876298c4739aec7a4e807b',
    messagingSenderId: '858453983778',
    projectId: 'the-crane-e2ff1',
    storageBucket: 'the-crane-e2ff1.appspot.com',
    iosBundleId: 'com.example.theCrane.RunnerTests',
  );
}
