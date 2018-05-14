#ifndef ADPCM_CODEC_H
#define ADPCM_CODEC_H

/*
	Encode and decode algorithms for
	Brian Schmidt's ADPCM used in QSound DSP
	
	2018 by superctr (Ian Karlsson).
*/

#include <stdint.h>

/**
 * Given (len) amount of PCM samples in buffer,
 * return encoded ADPCM samples in outbuffer.
 * Output buffer should be at least (len/2) elements large.
 */
void adpcm_encode(int16_t *buffer,uint8_t *outbuffer,long len);

/**
 * Given ADPCM samples in (buffer), return (len) amount of
 * decoded PCM samples in (outbuffer).
 * Output buffer should be at least (len*2) elements large.
 */
void adpcm_decode(uint8_t *buffer,int16_t *outbuffer,long len);

#endif
