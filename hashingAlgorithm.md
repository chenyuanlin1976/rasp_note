# hashing algorithm

A hashing algorithm is a mathematical function that  
mathematically maps data of any arbitrary size to a unique, fixed-size string of characters.  
This output is called a hash value, digest, or checksum.  
The transformation is strictly one-way (irreversible), meaning you cannot convert the final hash back into the original input.  

[Hash_function](https://en.wikipedia.org/wiki/Hash_function)  

## Cryptographic Hashes (Focus: Security)

1. SHA-256 (Secure Hash Algorithm 2): The industry standard for file integrity, digital signatures, and blockchain systems like Bitcoin.
2. SHA-3: The newest generation of the SHA family, built using a completely different mathematical structure (Keccak) for deep vulnerability protection.
3. Argon2 / Bcrypt: Special cryptographic hashes tailored specifically for password storage.  
   They are intentionally designed to be slow and resource-heavy to defeat brute-force and hardware acceleration attacks.
4. MD5 / SHA-1 (*Deprecated*): Former standards that are now fundamentally broken.  
   They suffer from high collision vulnerabilities and should never be used for security

## Non-Cryptographic Hashes (Focus: Speed)

1. MurmurHash: it created in 2008. Frequently used in databases and networking to distribute keys rapidly.
2. **CityHash**: it is a family of non-cryptographic hash functions created by Google in 2011.  
   It was designed with one main goal in mind: extreme speed when hashing strings, especially on modern 64-bit CPUs.
3. **FarmHash**: Google's FarmHash is a family of fast, non-cryptographic hash functions for strings and other data.  
   As the successor to **CityHash**, it is heavily optimized for speed on modern CPUs.
4. Purpose: Essential for building Hash Tables, checking simple memory caches, and indexing lookup keys in O(1) constant time.

[MurmurHash](https://en.wikipedia.org/wiki/MurmurHash)
[CityHash](https://github.com/google/cityhash)  
[FarmHash](https://github.com/google/farmhash)  
[XXHash](https://richardstartin.github.io/posts/xxhash)  
[xxhash](https://xxhash.com/)  

### The Anatomy of Speed: How MurmurHash Works

MurmurHash's genius lies in its simplicity and clever bit manipulation.

+ magic numbers: Those seemingly random constants (`0xcc9e2d51`, `0x1b873593`, etc.) aren't random at all.  
  They're carefully chosen to *maximize bit mixing and minimize patterns*.  
  Austin Appleby tested millions of combinations to find these optimal values.  
  And `0xcc9e2d51`, `0x1b873593`, `0xe6546b64 / 4` are prime numbers.
+ The mixing process: Each 4-byte chunk goes through a multiplication, rotation, and XOR dance  
  that ensures even tiny input changes create massive output changes (*avalanche effect*).
+ The finalization: The fmix32 function ensures that even if the main loop didn't fully mix the bits, the final hash will be well-distributed.

### Why Was CityHash Created?

Before **CityHash**, algorithms like *MurmurHash* were the standard choice for hash tables and quick string lookups.  
Google needed something even faster for heavy, data-intensive internal services like search indexing and large-scale hash tables.  
**CityHash was optimized to take full advantage of modern CPU architecture features**:  

+ 64-bit processing: Works on large word sizes natively.
+ Instruction-level parallelism: Structured so CPUs can execute multiple instructions simultaneously (pipelining).
+ Unaligned memory reads: Quickly loads 64-bit chunks without needing strict memory alignment.

### Why Did Google Create FarmHash?

FarmHash is a family of non-cryptographic hash functions introduced by Google in 2014.  
It is the direct successor to CityHash, created by the same primary author to fix CityHash's flaws and leverage modern CPU architectures even more efficiently.  

If *CityHash* was built for *general 64-bit speed*,  
**FarmHash** was built for **hardware versatility**, maximum raw performance, and strict output determinism (via "**Fingerprints**").

While CityHash was fast, it had 2 major limitations:  

+ Architecture Sensitivity: CityHash's performance varied significantly when moving between different CPU types (e.g., x86 vs. ARM)  
  or CPUs with different instruction sets (e.g., SSE4.2 vs. AVX).  
+ Lack of Compile-Time/Runtime Adaptation: CityHash didn't easily adapt to hardware capabilities at runtime to squeeze out optimal instruction-level parallelism.

FarmHash was written to address this by using conditional compilation and architecture detection.  
It automatically selects the optimal variant for the specific CPU running the code-utilizing specialized vector/SIMD instructions (like SSE4.2 or AES-NI) when available.

### XXHash hash algorithm

XXHash is a fast (the XX stands for extremely) hash algorithm designed by Yann Collet.
The algorithm is fast (and only faster than alternatives for larger inputs) for 2 reasons:

+ Hashing one byte at a time is slow: much faster to hash ints or longs.
+ Multiplications are slow but can be pipelined to remove data dependencies: replace total order with partial order.

The XXHash algorithms separate the input stream of bytes into 4 independent streams:  

+ *each 32 bits wide in XXHash32*;  
+ *each 64 bits wide in XXHash64*.  

The same operations are applied to the elements of each stream in sequence.  

## hash functions use multiplication overflow

In hash functions, *multiplication overflow* is **NOT** an error.  
it is a deliberate and essential feature used *to achieve pseudo-randomness and scramble data efficiently*.  
While standard software applications treat arithmetic overflow as a bug,  
non-cryptographic hash functions rely on it to map unbounded inputs into a fixed-size integer space.

+ Natural Modulo: take the advantage of HW register.
+ Efficiency: when an `unsigned int` overflows, the HW ignore the the bits over 32-bits.
+ Avalanche Effect: scramble data

NOTICE: In C, `unsigned int` overflow is defined to wrap around, while `signed int` overflow causes **undefined behavior**.

## common hashing algorithm

+ Fibonacci Hashing
+ FNV-1 / FNV-1a Hashing
+ Polynomial Rolling Hash

## prime numbers

+ Prime Number Advantage: Using a prime number helps distribute hash values more evenly,  
  reducing the likelihood of hash collisions (different strings producing the exact same integer).
+ Bitwise Optimization: Using bit shifts to optimize multiplication is more efficient.  

1. Golden ratio = 0.6180339887498949; the followings are the closet prime number to max unsigned value * golden ratio  
   + 8-bits,  the closest prime number = 157 = 0x9d  
   + 16-bits, the closest prime number = 40507 = 0x9e3b  
   + 32-bits, the closest prime number = 2654455771 = 0x9e37c7db  
2. e = 2.718281828459045; the followings are the closet prime number to max unsigned value / e  
   + 8-bits,  the closest prime number = 97 = 0x61  
   + 16-bits, the closest prime number = 24109 = 0x5e2d  
   + 32-bits, the closest prime number = 1580030171 = 0x5e2d58db  
3. pi = 3.141592653589793; the followings are the closet prime number to max unsigned value / pi  
   + 8-bits,  the closest prime number = 83 = 0x53  
   + 16-bits, the closest prime number = 20857 = 0x5179  
   + 32-bits, the closest prime number = 1367130559 = 0x517cc1bf  
