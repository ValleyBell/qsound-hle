# Capcom QSound HLE

This repository contains various files that were used in order to make a proper high-level emulator for Capcom QSound.

The QSound chip (labelled DL-1425) consists of a DSP16A digital signal processor with a mask-programmed ROM. It was used commonly in Capcom's CP System II system.   
It supports playback of 16 PCM channels (loopable) and 3 ADPCM channels (one-shot). It supports FIR filters and echo to enhence sound quality.
The DSP program was written by Brian Schmidt and shares similarities (such as the ADPCM algorithm) with his other famous DSP, the BSMT2000.

## Files
- qsound\_dl-1425.asm
  Disassembly of the program ROM.
- old/qsound\_vb.c/h
  A pretty straight port of the QSound program to C. Reference offsets of the original program ROM are noted in comments.  
  The code originates from [libvgm](https://github.com/ValleyBell/libvgm/) and was slightly modified in order to remove libvgm-dependencies.
- qsound\_vb.c/h
  New emulator written from scratch by ctr. Designed to be fast and produce accurate output.

## Notes
- There is no known game that uses the ADPCM channels.
- The QSound program supports two different modes. The second mode features an additional filter. No game is known to use the second mode.
- There is an alternate pan table at 0x140-0x160 in the ROM. Using it will disable the filter and produce a linear panning transition.
