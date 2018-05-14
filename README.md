# Capcom QSound HLE

This repository contains various files that were used in order to make a proper high-level emulator for Capcom QSound.

QSound is a program ROM labelled DL-1425 for the DSP16A Digital Signal Processor. It was used commonly in Capcom's CP System II system.   
It supports playback of 16 PCM channels (loopable) and 3 ADPCM channels (one-shot). It supports FIR filters and echo to enhence sound quality.

## Files
- qsound\_dl-1425.asm
  Disassembly of the program ROM.
- qsound\_vb.c/h
  A pretty straight port of the QSound program to C. Reference offsets of the original program ROM are noted in comments.  
  The code originates from [libvgm](https://github.com/ValleyBell/libvgm/) and was slightly modified in order to remove libvgm-dependencies.

## Notes
- There is no known game that uses the ADPCM channels.
- The QSound program supports two different modes. The second mode features an additional filter. No game is known to use the second mode.
