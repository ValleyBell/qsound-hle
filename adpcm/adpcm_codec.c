/*
	Encode and decode algorithms for
	Brian Schmidt's ADPCM used in QSound DSP
	
	2018 by superctr (Ian Karlsson).
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "math.h"

#define CLAMP(x, low, high)  (((x) > (high)) ? (high) : (((x) < (low)) ? (low) : (x)))

int16_t adpcm_table[16] = {
	154, 154, 128, 102, 77, 58, 58, 58,
	58, 58, 58, 58, 77, 102, 128, 154
};

void adpcm_encode(int16_t *buffer,uint8_t *outbuffer,long len)
{
	long i=0;
	
	int step_size = 10;
	
	int history = 0;
	uint8_t buf_sample;
	int nibble = 0;
	
	for(i=0;i<len;i++)
	{
		int step = (*buffer++) - history;
		step = (step / step_size)>>1;
		step = CLAMP(step, -8, 7);
		
		if(nibble)
			*outbuffer++ = buf_sample | (step&15);
		else
			buf_sample = (step&15)<<4;
		nibble^=1;
		
		int32_t delta = ((1+abs(step<<1)) * step_size)>>1;
		if(step <= 0)
			delta = -delta;
		history += delta;
		history = CLAMP(history, -32768,32767);
		
		step_size = (step_size * adpcm_table[8+step])>>6;
		step_size = CLAMP(step_size, 1, 2000);
	}
}

void adpcm_decode(uint8_t *buffer,int16_t *outbuffer,long len)
{
	long i=0;
	
	int step_size = 10;
	
	int history = 0;
	int nibble = 0;
	
	for(i=0;i<len;i++)
	{
		int8_t step = (*(int8_t*)buffer)<<nibble;
		step >>= 4;
		if(nibble)
			buffer++;
		
		nibble^=4;
		
		// delta = (0.5 + abs(step)) * step_size
		int32_t delta = ((1+abs(step<<1)) * step_size)>>1;
		if(step <= 0)
			delta = -delta;
		history += delta;
		history = CLAMP(history,-32768,32767);
		
		*outbuffer++ = history;
		
		step_size = (adpcm_table[8+step] * step_size) >> 6;
		step_size = CLAMP(step_size, 1, 2000);
	}
}
