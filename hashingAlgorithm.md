# hashing algorithm

A hashing algorithm is a mathematical function that  
mathematically maps data of any arbitrary size to a unique, fixed-size string of characters.  
This output is called a hash value, digest, or checksum.  
The transformation is strictly one-way (irreversible), meaning you cannot convert the final hash back into the original input.  

[CityHash](https://github.com/google/cityhash)  
[FarmHash](https://github.com/google/farmhash)  
[XXHash](https://richardstartin.github.io/posts/xxhash)  
[xxhash](https://xxhash.com/)  

## Cryptographic Hashes (Focus: Security)

1. SHA-256 (Secure Hash Algorithm 2): The industry standard for file integrity, digital signatures, and blockchain systems like Bitcoin.
2. SHA-3: The newest generation of the SHA family, built using a completely different mathematical structure (Keccak) for deep vulnerability protection.
3. Argon2 / Bcrypt: Special cryptographic hashes tailored specifically for password storage.  
   They are intentionally designed to be slow and resource-heavy to defeat brute-force and hardware acceleration attacks.
4. MD5 / SHA-1 (*Deprecated*): Former standards that are now fundamentally broken.  
   They suffer from high collision vulnerabilities and should never be used for security

## Non-Cryptographic Hashes (Focus: Speed)

1. MurmurHash / CityHash: Frequently used in databases and networking to distribute keys rapidly.
2. **FarmHash**: Google's FarmHash is a family of fast, non-cryptographic hash functions for strings and other data.  
   As the successor to **CityHash**, it is heavily optimized for speed on modern CPUs.
3. Purpose: Essential for building Hash Tables, checking simple memory caches, and indexing lookup keys in O(1) constant time.

## The Anatomy of Speed: How MurmurHash Works

MurmurHash's genius lies in its simplicity and clever bit manipulation.

+ magic numbers: Those seemingly random constants (`0xcc9e2d51`, `0x1b873593`, etc.) aren't random at all.  
  They're carefully chosen to *maximize bit mixing and minimize patterns*.  
  Austin Appleby tested millions of combinations to find these optimal values.  
  And `0xcc9e2d51`, `0x1b873593`, `0xe6546b64 / 4` are prime numbers.
+ The mixing process: Each 4-byte chunk goes through a multiplication, rotation, and XOR dance  
  that ensures even tiny input changes create massive output changes (*avalanche effect*).
+ The finalization: The fmix32 function ensures that even if the main loop didn't fully mix the bits, the final hash will be well-distributed.

## XXHash hash algorithm

XXHash is a fast (the XX stands for extremely) hash algorithm designed by Yann Collet.
The algorithm is fast (and only faster than alternatives for larger inputs) for 2 reasons:

+ Hashing one byte at a time is slow: much faster to hash ints or longs.
+ Multiplications are slow but can be pipelined to remove data dependencies: replace total order with partial order.

The XXHash algorithms separate the input stream of bytes into 4 independent streams:  
*each 32 bits wide in XXHash32*; *64 bits wide in XXHash64*.  
The same operations are applied to the elements of each stream in sequence.  
