import 'package:mfcc/mfcc.dart';

main() {
  var sampleRate = 16000;
  var windowLength = 1024;
  var windowStride = 512;
  var fftSize = 512;
  var numFilter = 20;
  var numCoefs = 13;
  var mySignal = List<double>.generate(16000, (i) => i.toDouble());
  var features = MFCC.mfccFeats(mySignal, sampleRate, windowLength, windowStride, fftSize, numFilter, numCoefs);
  print('Generated ${features.length} x ${features[0].length} MFCC features from signal of length ${mySignal.length}');
}
