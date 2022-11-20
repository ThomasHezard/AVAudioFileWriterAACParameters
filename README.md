# Issues with parameters of AVAudioFile writer for MPEG4-AAC encoding

## [TL;DR]

After encountering several issues while trying to write AAC-encoded file using [`AVAudioFile`](https://developer.apple.com/documentation/avfaudio/avaudiofile) (more precisely [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init)), I exprimented in depth with the [encoder settings](https://developer.apple.com/documentation/avfoundation/audio_settings/encoder_settings) and ended up with the following conclusions:  
- [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) is not properly implemented: 
    - It crashes in a non-catchable way when used in conjunction with the [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey), which seems a major bug.
    - All other parameters from the settings dictionary seem dicarded.
- [`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) is not properly implemented:
    - This parameter seems systematically discarded.
- [`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey) and [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey) seem systematically discarded, however that may be consistent wiht the MPEG4-AAC specifications.
- [`AVEncoderBitRateKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratekey) acceptable values are unclear and undocumented:
    - Some bitrate values are accepted while other trigger exception at [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init). It seems that any value >= 64 kbps is acceptable, but I'm not sure about that. Proper documentation would be appreciated.

---

## Introduction

This repository contains a swift script demonstrating issues encountered with [`AVAudioFile`](https://developer.apple.com/documentation/avfaudio/avaudiofile) while trying to set parameters for audio data encoding with AAC codec.    

This work has been motivated by:
- A rather incomplete documentation of [`AVAudioFile`](https://developer.apple.com/documentation/avfaudio/avaudiofile), and especially of the [encoder settings](https://developer.apple.com/documentation/avfoundation/audio_settings/encoder_settings).
- The difficulty I had to properly set the AAC codec parameters using the settings dictionnary on [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init).


## What this script does

> ⚠️ This code might not be the most elegant one as I'm pretty new to the swift language (as an audio developer on iOS, I usually code with a mix of C, C++ and Obj-C), so thank you for your indulgence on code quality 🙏

1. Read a WAV audio file with [`AVAudioFile`](https://developer.apple.com/documentation/avfaudio/avaudiofile) (the example in this repo is an extract from the song [_**Unity**_ by _**TheFatRat**_](https://soundcloud.com/thefatrat/thefatrat-unity-1) which is excplicitely copyright-free).

2. Write the read frames into an AAC-encoded audio file with an [`AVAudioFile`](https://developer.apple.com/documentation/avfaudio/avaudiofile) with various encoding settings, without any channel layout or sample rate conversion.  
    
    All settings tested share the following parameters:  
        - audio codec: AAC (MPEG4), using Apple's format ID [`kAudioFormatMPEG4AAC`](https://developer.apple.com/documentation/coreaudiotypes/kaudioformatmpeg4aac)  
        - sample rate: same as original wav file: 44100 Hz.  
        - channel layout: same as original wav file: stereo.  
    
    The variable parameters are the following:  
        - Bit rate strategy ([`AVEncoderBitRateStrategyKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratestrategykey)): [constant](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_constant), [long-term average](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_longtermaverage), [variable constrained](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variableconstrained), [variable](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable).  
        - Bit rate value ([`AVEncoderBitRateKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratekey)): 32 kbps, 64 kbps, 96 kbps, 128 kbps, 192 kbps, 320 kpbs.  
        - Bit rate per channel value ([`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey)): 32 kbps, 64 kbps, 96 kbps, 128 kbps, 192 kbps, 320 kpbs.  
        - Encoder quality ([`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey)): [min](https://developer.apple.com/documentation/avfaudio/avaudioquality), [low](https://developer.apple.com/documentation/avfaudio/avaudioquality), [medium](https://developer.apple.com/documentation/avfaudio/avaudioquality), [high](https://developer.apple.com/documentation/avfaudio/avaudioquality), [max](https://developer.apple.com/documentation/avfaudio/avaudioquality).  
        - Encoder quality for VBR ([`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey)): [min](https://developer.apple.com/documentation/avfaudio/avaudioquality), [low](https://developer.apple.com/documentation/avfaudio/avaudioquality), [medium](https://developer.apple.com/documentation/avfaudio/avaudioquality), [high](https://developer.apple.com/documentation/avfaudio/avaudioquality), [max](https://developer.apple.com/documentation/avfaudio/avaudioquality).  
        - Extension (file format): `m4a` or `caf`.  
    
    All combinations between these parameters have been tested, except that  
        - [`AVEncoderBitRateKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratekey) and [`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) are not set at the same time, as they both control the bitrate,  
        - [`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey) and [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey) are not set at the same time, as they both control the encoding quality.
    
    ⚠️ NB: I did not experiment with the [`AVEncoderBitDepthHintKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitdepthhintkey) as the bit depth is not relevant for the MPEG4-AAC codec.

3. For each encoded file:
    - the actual bitrate of the resulting file is read using `afinfo`,
    - the MD5 checksum of the encoded file is computed (for file comparisons),
    - the encoded file is decoded into standard AIFF file and the MD5 checksum of the AIFF file is computed (for audio content comparisons).

4. All the settings are stored into a dictionnary and after some testing and analysis, I added a few meaningfull analysis of the results with console outputs.


## What I learnt about the parameters behaviours: observations O-1 to O-4

> ⚠️ All these observations have been made after running the script on a macBook Pro 14-inch 2021 with an M1 Pro CPU running under macOS 13.0. However, they are fully consistent with what I experienced on both iOS and macOS since I started using AVAudioFile on 2017.

O-1. About the [`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey) and [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey) values

  - These settings do not seem to have any influence on the encoded file. For a given strategy and a given bitrate, the audio content of the encoded files are the same whatever the value of [`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey) or [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey). The `m4a` files might differ even though their content are the same, I did not dig into that but that may come from the date of file creation being inserted in the `m4a` metadata or something like that.

O-2. About the [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) strategy

  - Whatever the other parameters from the settings dictionnary are, the encoded file's bitrate is always precisely 126348 bps.
  - If the [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey) key is present in the settings dictionnary (with whatever value from the [`AVAudioQuality`](https://developer.apple.com/documentation/avfaudio/avaudioquality) enum) when the strategy is set to [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable), [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init) crashes with a non-catchable error of type [`NSInvalidArgumentException`](https://developer.apple.com/documentation/foundation/nsinvalidargumentexception).  
  These cases have been removed from the script to avoid these crashes but you can easily restore them by commenting lines 216 and 233, or lines 299 and 332.

O-3. About the [`AVEncoderBitRateKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratekey) value

  - A bitrate of 32000 bps systematically makes [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init) throw (in a catchable way), unless the strategy is set to [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable), which is consistent with the observation O-2 ([`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) seems to discard all parameters from the settings dictionnary).
  - Other values from my test are fine. I experimented with a few other values, it seems that any value >= 64 kbps is acceptable, but I'm not sure about that.

O-4. About the [`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) value

  - This setting does not seem to have any influence on the encoded file. For any value of [`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) and a given strategy (the quality settings has no influence as seen in O-1), the bitrate of the encoded audio file is always the same:  
    - Constant strategy gives a bitrate of 128221 bps,
    - LongTermAverage strategy gives a bitrate of 128383 bps,
    - VariableConstrained strategy gives a birate of 130531 bps,
    - Variable strategy gives a bitrate of 126348 bps (see 2. above).


## What seems wrong in the behaviour of [`AVAudioFile`](https://developer.apple.com/documentation/avfaudio/avaudiofile) AAC encoding: conclusions C-1 to C-4

MPEG4-AAC actually has many different versions anbd variations, and the AVFoundation documentation does not specify which one is implemented when using the [`kAudioFormatMPEG4AAC`](https://developer.apple.com/documentation/coreaudiotypes/kaudioformatmpeg4aac) format ID.  
However, when comparing to standard implementation, like [`FDK AAC`](https://github.com/mstorsjo/fdk-aac) or the different AAC encoders included in [`ffmpeg`](https://trac.ffmpeg.org/wiki/Encode/AAC), we can reasonably make the following conclusions.

C-1. **[`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) is not properly implemented.**  

  - AAC variable encoding strategy generally works with a `quality` parameter within a given range, each possible value corresponding to an approximate bitrate target. When the settings dictionnary specify the [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) strategy and a [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey) value, [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init) crashes (see O-2), where I would expect it to work like [`FDK AAC`](https://github.com/mstorsjo/fdk-aac) or [`ffmpeg`](https://trac.ffmpeg.org/wiki/Encode/AAC).

  - Other parameters ([`AVEncoderBitRateKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratekey), [`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) and [`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey)) seem to be discarded when stretagy is [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) (see O-2).

C-2. **[`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) is not properly implemented.**  

  - Values associated to the [`AVEncoderBitRatePerChannelKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitrateperchannelkey) seem completely discarded, whatever the other paramers are in the settings dictionnary (see O-4).

C-3. **[`AVEncoderBitRateKey`](https://developer.apple.com/documentation/avfaudio/avencoderbitratekey) acceptable values are unclear and undocumented.**  

  - 32 kbps always triggers an exception in [`AVAudioFile.init(forWriting:settings:)`](https://developer.apple.com/documentation/avfaudio/avaudiofile/1390840-init), other standard values in my tests (64 kbps, 96 kbps, 128 kbps, 320 kpbs) seem to work fine. I did additional testing and it seems that any value >= 64 kbps is acceptable, but I'm not sure about that (see O-3). Proper documentation would be appreciated.

C-4 **[`AVEncoderAudioQualityKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualitykey) and [`AVEncoderAudioQualityForVBRKey`](https://developer.apple.com/documentation/avfaudio/avencoderaudioqualityforvbrkey) are systematically discarded.**  

  - I'm not sure if MPEG4-AAC has a quality/complexity setting like other codec, so this behaviour may be expected, except for the [`AVAudioBitRateStrategy_Variable`](https://developer.apple.com/documentation/avfaudio/avaudiobitratestrategy_variable) strategry (see C-1 and O-1).
