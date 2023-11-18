# Rob Northen Decompressor

Currently this project only decompresses method 1 rnc.
This project is for the SuperFX chip.

# Structures 
## Read Buffer

The read buffer is repsonsible for reading bytes from 
the ROM, assembling those bytes into words (the words 
are stored low endian), and decoding the bitstream into
16-bit values.

### Parrameters and Initialization
The buffer has the following parameters
 * count : how many bits remain in the word-buffer
 * word  : the current word-buffer
 * index : the location in the rom data to read from next
 * 


# Setup
You must define a RNC_UNPACK memory segment in the GSU memory area.
Different from normal RNC, the lookback only supports 6kib.