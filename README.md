# AVAudioFile writer AAC parameters issue

This repo contains an Xcode playground demonstrating an issue I have with `AVAudioFile` while trying to encode audio data with AAC codec.     
My issue can be summarized as: 
**_I can't find a way to control AAC encoding parameters when writing audio data into an AAC-encoded audio file (M4A or CAF file format) using an AVAudioFile._** 

## What this code do

- Read a WAV audio file with `AVAudioFile` (the example in this repo is an extract from `Unity` by `TheFatRat` which is a copyright-free song).
- Write the read frames into an AAC-compressed audio file with an `AVAudioFile` for various encoding settings, without any channel layout or sample rate conversion.

All settings share the following parameters:
- audio codec: AAC (MPEG4), using Apple's format ID `kAudioFormatMPEG4AAC`
- sample rate: same as original wav file, 48 kHz.
- channel layout: same as original wav file, stereo.

The variable parameters are the following:
- Bit rate strategy: constant, long-term average, variable constrained, variable.
- Bit rate per channel value: 32, 48, 64, 96, 128.
- Encoder quality: min, low, medium, high, max.
- Extension (file type): M4A or CAF. NB: I intentionally did not use AVAudioFileTypeKey for compatibility reasons.

## What I expect to obtain

- File size should highly depend on bit rate.
- Perceived audio quality should depend on bit rate, bit rate strategy and encoder quality.
- For the same set of settings, M4A and CAF files should be almost the same size, as the same codec is used.

## What I obtain

- All CAF files are exactly the same size, and seems to be exactly the same (I compared a few of them with `diff`).
- All M4A files are exactly the same size, but binary comparison says they are different (although I know that some codecs can use some randomness, maybe it is the case here).
- Perceived audio quality is the same for all files (they should not, I know audio codecs, you can trust me on this one ^^).

## Additional experiments

- I tried to remove the encoder quality settings and/or the bit rate parameters, the results are the same.
- I tried to use the BitRate parameter instead of the BitRatePerChannel, results are the same.
- The problem is the same in Obj-C (my original use case where I detected the issue) and in swift (this demonstrating playground).
- The problem is the same if I use another common format in the reader and writer processing formats (output files are exactly the same).

## My questions

- Is there an issue with my settings dictionary? I spent quite some time on the internet and I don't understand what I do wrong.
- If not, is there a known issue with `AVAudioFile` on this topic?

**_If you have any idea, feel free to contact me ;)_**
