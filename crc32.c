#include <stdio.h>
#include <inttypes.h>
#include <stdlib.h>

uint32_t table_value(uint32_t r) {
  for(int j = 0; j < 8; ++j) {
    r = (r & 1? 0: (uint32_t)0xEDB88320L) ^ r >> 1;
  }
  return r ^ (uint32_t)0xFF000000L;
}

void crc32(const void *data, size_t nBytes, uint32_t* crc) {
  static uint32_t crctab[256];
  size_t i;
  if(!*crctab) {
    for(i = 0; i < 256; i++) {
      crctab[i] = table_value(i);
    }
  }
  for(i = 0; i < nBytes; i++) {
    *crc = crctab[(uint8_t)*crc ^ ((uint8_t*)data)[i]] ^ *crc >> 8;
  }
}

int main(int argc, char** argv) {
  FILE *fp;
  char buf[32768];
  uint32_t crc = 0;
  size_t flen=0;
  if (argc<2) {
    fprintf(stderr,"usage: %s <file>\n",argv[0]);
    exit(1);
  }
  fp=fopen(argv[1], "rb");
  if(fp==NULL) { 
    perror(argv[1]);
    exit(1);
  }
  while(!feof(fp) && !ferror(fp)) {
    size_t nBytes=fread(buf, 1, sizeof(buf), fp); 
    crc32(buf, nBytes, &crc);
    flen += nBytes;
  }
  if(!ferror(fp)) {
    printf("%u %ld\n", crc, flen);
    fclose(fp);
  }
  return 0;
}
