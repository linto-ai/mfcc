/*
Copyright (c) 2019 Rudy Baraglia Linagora.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

import 'package:fft/fft.dart';
import 'dart:math';

/// Converts hertz [freq] to mel
double hertz_to_mel(double freq){
  return 1127 * log(1 + freq / 700);
}

/// Converts [mel] value to hertz
double mel_to_hertz(double mel) {
  return 700 * (exp(mel / 1127) - 1);
}

/// Returns the log of a [value]... safely.
///
/// If [value] <=0 return the smallest possible value
double safe_log(double value){
  if (value <= 0) {
    return log(double.minPositive);
  } else {
    return log(value);
  }
}

/// Class to extract MFCC features from a signal.
/// 
/// There are 2 ways to use this class:
/// - Use the static method mfcc() to extract features from a signal.
/// - Intantiate MFCC to process frames on the go with processFrame() or processFrames().
/// 
/// MFCC are generated on each windows by: 
/// 1. (Optional) Aplying pre-Emphasis
/// 1. Computing Spectrum 
/// 2. Applying triangular filter in the MEL domain.
/// 3. Computing log for each band
/// 4. Appying Discrete Cosinus Transform
/// 5. (Optional) Replace first value by the window log-Energy.
class MFCC {
  /// FFT size
  int _fftSize;
  /// The number of mel filters
  int _numFilters;
  /// Number of output values
  int _numCoefs;
  /// The mel filters triangle windows indexes, generated once
  List<List<double>> _fbanks;
  /// If set to true, replace mfcc first value with spectrum logenergy
  bool _energy;
  /// PreEmphasis parameters
  bool _useEmphasis;
  /// Emphasis factor
  double _emphasis;
  /// Previous frame last value for continue preEmphasis
  num _lastValue = 0.0;


  MFCC(int sampleRate, int fftSize, int numFilters, int numCoefs, {bool energy = true, double preEmphasis = 0.97}){
    _fftSize = fftSize;
    _numFilters = numFilters;
    _numCoefs = numCoefs;
    if (!energy) {
      _numCoefs += 1;
    }
    _energy = energy;
    _useEmphasis = (preEmphasis != null);
    _emphasis = preEmphasis;

    _fbanks = MFCC.filterbanks(sampleRate, _numFilters, ((_fftSize / 2) +1).toInt() );
  }

  static List<double> preEmphasis(List<num> signal, double emphasisFactor, {num lastValue = 0.0})  {
    /// Apply preEmphasis filter on given signal.
    var empSignal = List<double>(signal.length);
    var swSig = [lastValue] + signal.sublist(0, signal.length - 1);
    for (var i =0; i < signal.length; i++) {
      empSignal[i] = signal[i] - swSig[i] * emphasisFactor;
    }
    return empSignal;
  }

  /// Returns the mel filters
  ///
  /// 1. Linearly splits the frequency interval using the mel scale.
  /// 2. Generates triangular overlapping windows
  /// 3. Generates filter coeficient for each window
  /// 4. Returns [num_filt] filters of length [n_fft]
  static List<List<double>> filterbanks(int samplerate, int num_filt, int n_fft){
    var interval = hertz_to_mel(samplerate.toDouble()) / (num_filt + 1);
    var grid_mels = List<double>.generate(num_filt + 2, (v) => v * interval);
    var grid_hertz = grid_mels.map((v) => mel_to_hertz(v)).toList();
    var grid_indexes = grid_hertz.map((v) => (v * n_fft / samplerate).floor()).toList();

    var filters = List<List<double>>(num_filt);
    for (var i = 0; i < num_filt; i ++ ){
      var left = List<double>.generate(grid_indexes[i + 1] - grid_indexes[i], (v) => v / (grid_indexes[i + 1] - grid_indexes[i]));
      var right = List<double>.generate(grid_indexes[i + 2] - grid_indexes[i + 1], (v) => v  / (grid_indexes[i + 2] - grid_indexes[i+1])).reversed.toList();
      var filter = [List<double>.filled(grid_indexes[i], 0.0), left, [1.0], right.sublist(0,right.length - 1), List<double>.filled(n_fft - grid_indexes[i+2], 0.0)].expand((x) => x).toList();
      filters[i] = filter;

    }
    return filters;
  }

  /// Returns the power spectrum of a given [frame].
  static List<double> power_spectrum(List<double> frame, fft_size){
    var fft = FFT().Transform(frame.sublist(0, fft_size));
    return fft.sublist(0, (fft_size / 2 + 1).round()).map((v) => (pow(v.real, 2) + pow(v.imaginary, 2)) / fft_size).toList();
  }

  /// Maps the power spectrum over the mel [filters] to obtains a condensed spectrogram on the mel scale.
  static List<double> mel_coefs(List<double> power_spec, List<List<double>> filters){
    var n_filt = filters.length;
    var result = List<double>(n_filt);
    for (var i = 0; i < n_filt; i++){
      num sum = 0;
      for (var j = 0; j < power_spec.length; j++){
        sum += power_spec[j] * filters[i][j];
      }
      result[i] = sum;
    }
    return result.map((v) => safe_log(v)).toList();
  }

  /// Returns the discrete cosinus transform.
  ///
  /// Uses the [scipy](https://docs.scipy.org/doc/scipy-0.14.0/reference/generated/scipy.fftpack.dct.html) type-II dct implementation:
  ///
  /// `y(k) = 2 * sum{n ∈ [0,N-1]} x(n) * cos(pi * k * (2n+1)/(2 * N)), 0 <= k < N.`
  ///
  /// if norm is set to true apply a scaling factor f to y(k) as followed:
  ///
  /// - `f = sqrt(1/(4*N)) if k = 0`
  /// - `f = sqrt(1/(2*N)) otherwise.`
  ///
  static List<double> dct(List<double> x, bool norm){
    var result = List<double>(x.length);
    var N = x.length;
    var sum = 0.0;
    var scaling_factor0 = sqrt(1 / (4 * N));
    var scaling_factor = sqrt(1 / (2 * N));
    for (var k = 0; k < N; k++){
      sum = 0.0;
      for (var n = 0; n < N ; n++) {
        sum += x[n] * cos(pi * k * (2 * n + 1)/(2 * N));
      }
      sum *= 2;
      if (norm){
        if (k == 0){
          sum = sum * scaling_factor0;
        } else {
          sum = sum * scaling_factor;
        }
      }
      result[k] = sum;
    }
    return result;
  }

  /// Returns the MFCC values for the given frame
  List<double> process_frame(List<double> frame){
    if (_useEmphasis) {
      var v = frame.last;
      frame = preEmphasis(frame, _emphasis, lastValue: _lastValue);
      _lastValue = v;
    }
    var power_spectrum = MFCC.power_spectrum(frame, _fftSize);
    var mel_coefs = MFCC.mel_coefs(power_spectrum, _fbanks);
    var mfccs = MFCC.dct(mel_coefs, true).sublist(0, _numCoefs);
    if (_energy){
      mfccs[0] = safe_log(power_spectrum.reduce((a, b) => a + b)); // Replace first value with logenergy
    } else {
      return mfccs.sublist(1);
    }
    return mfccs;
  }
  /// Returns the MFCC values of a list of frames
  List<List<double>> process_frames(List<List<num>> frames){
    var mfccs = List<List<double>>();
    for (List<double> frame in frames){
      mfccs.add(process_frame(frame));
    }
    return mfccs;
  }
  /// Generates MFCC features from a [signal].
  /// 
  /// * [signal] - The signal to extract the features from.
  /// * [sampleRate] - The signal sampling rate -sample/s- (> 0).
  /// 
  /// MFCC are extracted using temporal sliding windows 
  /// * [windowLength] - Window length in number of samples (> 0 && <= [signal].length).
  /// * [windowStride] - Window stride in number of sample (> 0)
  /// 
  /// 
  /// * [fftSize] - Number of fft generated by window (> 0)
  /// * [numFilters] - Number of MEL filters (> 0)
  /// * [numCoefs] - Number of cepstral coefficient to keep (> 0 && <= [numFilters])
  /// * {[energy] = true} - If True, replaces the first value by the window log-energy.
  /// * {[preEmphasis] = 0.97} - Apply signal preEmphasis. If the value is null, does nothing.
  /// 
  /// 
  /// Throws [ValueError] if any value is off limit. 
  static List<List<double>> mfccFeats(List<num> signal, int sampleRate, int windowLength,
                                 int windowStride, int fftSize, int numFilters, int numCoefs, {bool energy = true, double preEmphasis = 0.97}) {
    if (sampleRate <= 0) throw ValueError('Sample rate must be > 0 (Got $sampleRate).');
    if (windowLength <= 0) throw ValueError('Window length must be > 0 (Got $windowLength).');
    if (windowStride <= 0) throw ValueError('Stride must be > 0 (Got $windowStride).');
    if (windowLength > signal.length) throw ValueError('Window length cannot be greater than signal length.(Got $windowLength > ${signal.length})');
    if (numFilters <= 0) throw ValueError('Number of filter must be positive (Got $numFilters).');
    if (numCoefs <= 0) throw ValueError('Number of coefficient must be positive (Got $numCoefs).');
    if (numCoefs > numFilters) throw ValueError('Number of coefficient must be inferior to the number of filters (Got $numCoefs > $numFilters).');

    var frames = splitSignal(signal, windowLength, windowStride);
    var processor = MFCC(sampleRate, fftSize, numFilters, numCoefs, energy: energy, preEmphasis: preEmphasis);
    return processor.process_frames(frames);

  }
  static List<List<num>> splitSignal(List<num> signal, int windowLength, int windowStride) {
    var nFrames = ((signal.length - windowLength) / windowStride).floor() + 1;
    var frames = List<List<num>>(nFrames);
    for (var i = 0; i < nFrames; i++) {
      frames[i] = signal.sublist(i * windowStride, (i * windowStride) + windowLength);
    }
    return frames;
  } 
}

class ValueError implements Exception {
  String errMsg = '';
  ValueError(String msg) {
    errMsg = msg;
  }
}