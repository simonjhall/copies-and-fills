copies-and-fills

SUMMARY

Replacement memcpy and memset functionality for the Raspberry Pi with the intention of gaining greater performance.
Coding with an understanding of single-issue is important.

Tested using a modified https://github.com/ssvb/ssvb-membench, from Siarhei Siamashka.
The testing involves lots of random numbers, iterating through sizes and source/destination alignments.
If you find a bug, please tell me!

To use: define the environment variable, LD_PRELOAD=/full/path/to/libcofi_rpi.so, then run program.

The inner loop of the misalignment path of memcpy is derived from the GNU libc ARM port. As a result "copies-and-fills" is licensed under the GNU Lesser General Public License version 2.1. See http://www.gnu.org/licenses/ for details.
To see the original memcpy, browse it here: http://sourceware.org/git/?p=glibc-ports.git;a=blob;f=sysdeps/arm/memcpy.S;hb=HEAD

Simon Hall

NOTES

memcpy:
Can be found in memcpy.s.
Compared to the generic libc memcpy, this one reaches performance parity at around ~150 bytes copies with any source/destination alignment and eventually gains 2-3x throughput, especially when the source buffer is uncached.
When taking the libc source and enabling the pld path, it certainly does improve. However the source alignment option appears to do nothing for performance yet greatly increases the code complexity.
In initial testing, some facts were found:
- despite the increase in free registers, copies via VFP were slower at peak by ~25%
- copying 32 bytes at a time with a single store-multiple gives the highest performance
- getting the destination 32b aligned gives a much greater throughput versus 4b-alignment
- some memcpys are of a fixed size, eg 1/2/4/8 byte in size
- byte transfers have a much worse performance than expected
- for misaligned transfers, 32b-aligned stms are the way forward with mov/orr byte shuffling; byte copies give very poor performance

The code deals with the special small sizes, then races to reach 32b alignment of the destination.
We then test for misalignment with the source. If the (source - dest alignment) & 3 != 0 then we use the misaligned path.
For the aligned path, we iterate through the data, 32 bytes at a time. We then handle a word at a time, then a byte.
For the misaligned path, we have to choose how misaligned we are - 1, 2, or 3 bytes. There is a custom path for each that does the appropriate shifts.

The key to this is prefetch of the source array. Prefetch instructions must be far from the load instruction, as it appears the load/store pipe is busy for a while after a large load instruction is issued.

Speeds of up to 680 MB/s have been achieved (effective 339 MB/s copy).

memset:
Can by found in memset.s.
Compared to the generic libc memset, this quickly reaches performance parity at around 100 bytes with any alignment.
On testing,
- it appears 32-byte stores yield ~1000-1100 MB/s, by two sequential 16-byte stores can reach 1300-1400 MB/s
- again 32b aligned destinations are good

The code 4-byte aligns the destination with a byte writer, then 32-byte aligns it with a word writer.
We then write two 2*16 bytes of data, then write words, then bytes.
No preload of destination data seems to be required.

Speeds of up to 1390 MB/s have been achieved. This is ~7x faster than the libc version.

VERSION HISTORY

09/07/2012, minor updates
01/07/2012, initial release

