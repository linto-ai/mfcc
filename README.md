![version](https://img.shields.io/github/manifest-json/v/lokhozt/mfcc) ![pub-version](https://img.shields.io/pub/v/mfcc)

A library to extract Mel-Frequency Cepstral Coefficients (MFCCs) from a signal.

## Usage

A simple usage example:

```dart
import 'package:mfcc/mfcc.dart';

void main() {
  var sampleRate = 16000;
  var windowLength = 1024;
  var windowStride = 512;
  var fftSize = 512;
  var numFilter = 20;
  var numCoefs = 13;
  List<double> mySignal = // ...
  var features = MFCC.mfccFeats(mySignal, sampleRate, windowLength, windowStride, fftSize, numFilter, numCoefs);
  
}
```

Streaming usage exemple:

```dart
import 'package:mfcc/mfcc.dart';
import 'dart:async';

void main() {
  var sampleRate = 16000;
  var windowLength = 1024;
  var windowStride = 512;
  var fftSize = 512;
  var numFilter = 20;
  var numCoefs = 13;

  var mfcc_proc = MFCC(sampleRate, fftSize, numFilter, numCoefs, energy: false, preEmphasis: 0.97);
  
  StreamController<List<double>> audioInput = StreamController<List<double>>(); // Stream on which the audio frame are pushed

  StreamController<List<double>> featureStreamCtrl = mfcc_proc.setStream(audioInput.stream); // Feature stream controller. 

  StreamSubscription<List<double>> featureSub = featureStreamCtrl.stream.listen((features) { // Feature stream subscription.
    doSomething(features); 
  })

  List<double> myFrame = ... // frame of length [windowLength]

  audioInput.add(myFrame);

  // doSomething is called with extracted features. 

  mfcc_proc.cancelStream();
  featureSub.cancel();
}
```

## Documentation
Package documentation is available [here](https://pub.dev/documentation/mfcc/latest/mfcc/mfcc-library.html). Generated using dartdoc. 

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/Lokhozt/mfcc/issues).

## LICENCE

This project is under aGPLv3 licence, feel free to use and modify the code under those terms. See LICENCE.