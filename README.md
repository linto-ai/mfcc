![version](https://img.shields.io/github/manifest-json/v/lokhozt/dartMFCC) ![pub-version](https://img.shields.io/pub/v/mfcc)

A library to extract Mel-Frequency Cepstral Coefficients (MFCCs) from a signal.

## Usage

A simple usage example:

```dart
import 'package:mfcc/mfcc.dart';

main() {
  var sampleRate = 16000;
  var windowLength = 1024;
  var windowStride = 512;
  var fftSize = 512;
  var numFilter = 20;
  var numCoefs = 13;
  List<num> mySignal = // ...
  var features = MFCC.mfccFeats(mySignal, sampleRate, windowLength, windowStride, fftSize, numFilter, numCoefs);
  
}
```

## Documentation
Package documentation is available [here](). Generated using dartdoc. 

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/Lokhozt/dartMFCC/issues).


