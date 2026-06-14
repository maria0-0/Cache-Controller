# Structural Direct-Mapped Cache Controller

This project implements a **purely structural** 32 KiB Direct-Mapped Write-Back Cache Controller with an 8 MiB Main Memory interface in SystemVerilog.

The entire cache array is implemented using explicit flip-flops and multiplexer routing rather than abstracted behavioral arrays, making this a completely hardware-accurate representation of cache memory down to the lowest logic level.


## Project structure

```
project/
│
├── src/                 # RTL source files
├── tb/                  # Testbenches
├── sim/                 # Simulation scripts and config
├── build/               # Build-related outputs (e.g., synthesis)
├── docs/                # Documentation, specs
└── Makefile             # Project-level build/sim control
```

## Requirements

Design and simulate a 32 KiB direct mapped cache, with 8-words block and 32 bit words.
Main Memory size is 8 MiB, the addressable unit is the word. The cache is write-back.


## Parameters

### Cache

$32 KiB = 2^5 \times 2^{10} B$. Considering that there are $32 bits = 4B = 2^2 B$ per each word, that
means that the cache size is $\frac{2^5 \times 2^{10}}{2^2}=2^3 \times 2^{10} words$. 
Since there are 8 words per block ($2^3 words/block$), the are $\frac{2^3 \times 2^{10}}{2^3}=2^{10}$ blocks in cache.

| Tag   | Index   | Block Offset| 
|-------|---------|-------------|
| 8bits | 10 bits | 3 bits      |

### Main Memory
Main memory is $8 MiB = 2^3 \times 2^{20} B$. Since the addressable unit is the word, and each word is 4B, there are $\frac{ 2^3 \times 2^{20}}{2^2}=2^{21}$ words in main memory. This means that the address word is 21 bits. Therefore, tag size is $21 -10 -3 = 8$ bits. 

The address issued from the cache controller to main memory is on $8+10=18$ bits, being made of tag and index.

### Offsets

| Tag (20:13) | Index (12:3) | Block Offset (2:0) |  
|-------------|--------------|---------------------|  
| 8 bits | 10 bits | 3 bits |


## Cache controller parameters

```verilog
parameter BLOCK_SIZE = 256; // bits (8 words * 4 B * 8 bits = 256 bits)
parameter ADDRESS_WIDTH = 21; //bits (3 + 10 + 8)
parameter INDEX_WIDTH = 10; //bits
parameter TAG_WIDTH = 8; //bits
parameter OFFSET_WIDTH = 3; //bits
parameter WORD_SIZE = 32; //bits
parameter NBLOCKS = 1024; // 2^10 blocks in cache
```

