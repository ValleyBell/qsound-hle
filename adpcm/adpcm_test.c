/*
	Build with
	gcc -o adpcm_test adpcm_test.c adpcm_codec.c
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "adpcm_codec.h"

int main(int argc, char* argv [])
{

	unsigned long i;

	printf("PCM -> QSound ADPCM conversion tool\n");
	printf("2018 by ctr\n");
	printf("Input format: signed 16 bit PCM little endian\n");
		
	if(argc<4)
	{
		printf("Usage: <e|d> <file> <destination file> \n");
		exit(EXIT_FAILURE);
	}

	char* mode = argv[1];
	char* file1 = argv[2];
	char* file2 = argv[3];

	int res;

	FILE* sourcefile;
	/* Load sample file */
	sourcefile = fopen(file1,"rb");
	if(!sourcefile)
	{
		printf("Could not open %s\n",file1);
		exit(EXIT_FAILURE);
	}
	fseek(sourcefile,0,SEEK_END);
	unsigned long sourcefile_size = ftell(sourcefile);
	rewind(sourcefile);
	uint8_t* source = (uint8_t*)malloc(sourcefile_size+1);
	uint8_t* dest = (uint8_t*)malloc(sourcefile_size*4+1);
	res = fread(source,1,sourcefile_size,sourcefile);
	if(res != sourcefile_size)
	{
		printf("Reading error\n");
		exit(EXIT_FAILURE);
	}
	fclose(sourcefile);

	int length;

	if(*mode == 'e')
	{
		length = sourcefile_size/2;
		if(length & 1)
			length++;	// make the size even

		printf("encoding... (len= %d)\n",length);
		adpcm_encode((int16_t*)source,dest,length);
		length /= 2;
	}
	
	else if(*mode == 'd')
	{
		length = sourcefile_size*2;

		printf("decoding... (len= %d)\n",length);
		adpcm_decode(source,(int16_t*)dest,length);
		length *= 2;
	}

	FILE *destfile;
	destfile = fopen(file2,"wb");
	if(!destfile)
	{
		printf("Could not open %s\n",file2);
		exit(EXIT_FAILURE);
	}
	for(i=0;i<length;i++)
	{
		putc(*((uint8_t*)dest+i),destfile);
	}
	fclose(destfile);
	printf("write ok %lu\n",length);

	free(source);
}
