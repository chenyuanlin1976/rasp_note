# Hashing algorithms

A hash function maps input of any size to a fixed-size value, the **hash** (or **digest**). Examples: SHA-256 always gives 256 bits; FNV-1a 32 gives 32 bits.

+ **Deterministic**: the same input always gives the same hash.
+ **Not unique**: there are more possible inputs than outputs, so different inputs can have the same hash (a **collision**). A good hash makes collisions rare and hard to find, not impossible.
+ **One-way only if cryptographic**: you can't feasibly recover the input from a cryptographic hash. Many fast non-cryptographic hashes are easy to invert or to attack with chosen inputs.

Hash functions fall into groups with different goals:

| Group | Goal | Examples | Use for |
| --- | --- | --- | --- |
| Cryptographic hash | Collision and preimage resistance against attackers | SHA-256, SHA-512, SHA-3, BLAKE2, BLAKE3 | File integrity against tampering, signatures, HMAC, Git/content addressing |
| Password hash (KDF) | Deliberately slow and memory-hard | Argon2id, scrypt, bcrypt, PBKDF2 | Storing passwords, deriving keys from passwords |
| Non-cryptographic hash | Speed and good distribution | MurmurHash3, xxHash, CityHash/FarmHash, FNV-1a | Hash tables, Bloom filters, sharding, deduplication without attackers |
| Keyed hash for hash tables | Speed plus resistance to chosen-input (HashDoS) attacks | SipHash | Hash tables fed with untrusted keys (Python, Rust) |
| Checksum / CRC | Detect accidental errors | CRC-32, Adler-32 | Network frames, files, flash images; not tamper-proof |

## 1. Cryptographic hashes

| Algorithm | Output | Status | Notes |
| --- | --- | --- | --- |
| MD5 | 128 bits | **Broken** (collisions found in seconds) | Only for non-security checksums of trusted data |
| SHA-1 | 160 bits | **Broken** (practical collision 2017, "SHAttered") | Legacy; Git also supports SHA-256 repositories |
| SHA-256 / SHA-512 (SHA-2 family) | 256 / 512 bits | Secure | The default choice; SHA-512 is often faster on 64-bit CPUs |
| SHA-3 (Keccak) | 224–512 bits | Secure | Standardized 2015; different design (sponge), not a replacement because SHA-2 is broken |
| BLAKE2b / BLAKE2s | Up to 512 / 256 bits | Secure | Faster than SHA-2 in software; `b2sum` |
| BLAKE3 | 256 bits (extendable) | Secure | Very fast, parallel (tree structure) |

+ SHA-256 and SHA-512 allow **length-extension attacks**: from `H(secret || msg)` an attacker can compute `H(secret || msg || extra)`.
  Don't build a MAC this way; use **HMAC** (`HMAC-SHA256`), or SHA-3/BLAKE2 keyed mode.
+ A plain hash proves integrity only if the hash itself comes from a trusted place (e.g. a signed release file or an HTTPS page).

### Password hashing

Never store passwords as plain SHA-256 or MD5: GPUs test billions of guesses per second. Password hashes are slow on purpose and use a random **salt** per password:

+ **Argon2id**: current recommendation (winner of the Password Hashing Competition 2015); tunable time, memory, and parallelism.
+ **scrypt**: memory-hard; older but still good.
+ **bcrypt**: widely available; limited to 72 bytes of password input.
+ **PBKDF2**: use only when required (e.g. FIPS); needs a high iteration count.

## 2. Non-cryptographic hashes

These are tuned for speed and even distribution. They are fine when inputs are not chosen by an attacker.

| Hash | Author / year | Output | Notes |
| --- | --- | --- | --- |
| FNV-1 / FNV-1a | Fowler, Noll, Vo, 1991 | 32/64/... bits | Tiny and simple; byte at a time, so slow for long input |
| MurmurHash3 | Austin Appleby, 2011 (Murmur1 2008) | 32 / 128 bits | Long-time default in many libraries (Hadoop, Cassandra, Guava) |
| CityHash | Google (Pike, Alakuijala), 2011 | 32/64/128 bits | Optimized for x86-64 strings |
| FarmHash | Google (Pike), 2014 | 32/64/128 bits | Successor of CityHash; selects platform-specific variants |
| xxHash (XXH32, XXH64, XXH3, XXH128) | Yann Collet, 2012 (XXH3 2019) | 32/64/128 bits | Among the fastest; XXH3 is also fast on small inputs; `xxhsum` |
| SipHash | Aumasson, Bernstein, 2012 | 64/128 bits | Keyed, defends hash tables against HashDoS |

Hash tables give **average** O(1) lookups. If an attacker can choose keys that all collide, lookups degrade to O(n) (HashDoS). That is why languages that hash untrusted input (Python's `str`, Rust's `HashMap`) use a randomly keyed SipHash instead of a fixed non-cryptographic hash.

### 2.1 MurmurHash3: multiply, rotate, XOR

Each 4-byte block is mixed and folded into the state:

```c
k *= 0xcc9e2d51;  k = rotl32(k, 15);  k *= 0x1b873593;   /* mix the block */
h ^= k;           h = rotl32(h, 13);  h = h * 5 + 0xe6546b64;   /* fold into the state */
```

A final **fmix32** step (`h ^= h >> 16; h *= 0x85ebca6b; h ^= h >> 13; h *= 0xc2b2ae35; h ^= h >> 16;`)
makes every input bit affect every output bit (the **avalanche effect**: flipping one input bit flips about half of the output bits).

The constants were chosen by testing how well they mix (Appleby's SMHasher test suite), not because they are prime.
`0xcc9e2d51` and `0x1b873593` happen to be prime; `0xe6546b64`, `0x85ebca6b`, and `0xc2b2ae35` are not.
What matters for the multipliers is that they are **odd**: multiplication by an odd number is invertible modulo 2^32, so no information is lost.

### 2.2 CityHash and FarmHash

+ **CityHash** reads 64-bit words with unaligned loads and is structured so the CPU can run several independent operations in parallel (instruction-level parallelism).
  It was tuned for x86-64; on other CPUs it is slower, and some variants use SSE4.2 CRC32 instructions.
+ **FarmHash** keeps the same ideas but chooses, at compile time, the best variant for the target (SSE4.1/4.2, AES-NI, or portable code).
  Because the result of `farmhash::Hash*()` may differ between platforms and versions, FarmHash also provides **Fingerprint** functions
  (`Fingerprint32/64/128`) whose output is guaranteed stable, for values you store or send.

### 2.3 xxHash

xxHash is fast because it avoids byte-at-a-time work and long dependency chains:

+ It processes the input in 16-byte (XXH32) or 32-byte (XXH64) stripes, split into **4 independent lanes** (4 × 32-bit or 4 × 64-bit accumulators).
  The lanes don't depend on each other, so the CPU can pipeline their multiplications.
+ At the end the lanes are merged and passed through an avalanche step.
+ XXH3 adds SIMD (SSE2, AVX2, NEON) for long inputs and special short paths for small inputs.

## 3. Simple hashes you can write yourself

**FNV-1a (32-bit)**: XOR each byte in, then multiply by the FNV prime.

```c
#include <stddef.h>
#include <stdint.h>

uint32_t fnv1a32(const void *data, size_t len)
{
    const uint8_t *p = data;
    uint32_t h = 0x811c9dc5u;          /* offset basis 2166136261 */

    for (size_t i = 0; i < len; i++) {
        h ^= p[i];
        h *= 0x01000193u;              /* FNV prime 16777619 */
    }
    return h;                          /* fnv1a32("hello", 5) == 0x4f9f2cab */
}
```

FNV-1 does the multiply before the XOR; FNV-1a has slightly better avalanche. 64-bit version: offset `0xcbf29ce484222325`, prime `0x100000001b3`.

**Polynomial rolling hash**: `h = h * B + c` for each character. Java's `String.hashCode()` uses `B = 31` (`"hello"` → 99162322).
Because the hash of a sliding window can be updated in O(1), it is the basis of the Rabin–Karp substring search.

**Fibonacci hashing**: map a hash (or integer key) to a table of `2^k` buckets by multiplying with `2^32 / φ` and keeping the **top** bits:

```c
static inline uint32_t fib_index(uint32_t h, unsigned k)    /* 1 <= k <= 32 */
{
    return (h * 0x9e3779b9u) >> (32 - k);    /* 0x9e3779b9 = round(2^32 / golden ratio) */
}
```

The top bits of the product depend on all input bits, so even keys like 0, 16, 32, ... spread across the table. Using `h % 2^k` (the low bits) would put them all in a few buckets.

## 4. Why overflow is a feature

Hash functions multiply and add on fixed-width unsigned integers and let the results **wrap around**:

+ Wrap-around is arithmetic modulo 2^32 (or 2^64) for free: the CPU simply drops the high bits.
+ The high bits of a product depend on many input bits; repeated multiply/shift/XOR spreads every input bit across the whole word.

C rules that matter here:

+ Unsigned overflow is defined (wraps modulo 2^N). **Signed overflow is undefined behavior**; always use `uint32_t` / `uint64_t`.
+ Watch integer promotion: `uint16_t` and `uint8_t` are promoted to (signed) `int` before arithmetic, so multiplying two `uint16_t` values can overflow `int` (UB).
  Cast first: `(uint32_t)a * b`.

## 5. Multipliers, primes, and table sizes

Where primes help, and where they don't:

+ **Table size with `h % size`**: a prime size spreads keys better when the hash itself is weak, because any regular pattern in the keys (e.g. all multiples of 8) is less likely to share a factor with the size.
+ **Table size `2^k` with a mask or Fibonacci hashing**: fast (no division). The hash must mix well, because only some bits are used.
+ **Multipliers**: must be **odd** (invertible mod 2^N) and have a "random-looking" bit pattern. Being prime is not required, though many published constants are prime.
+ **Shift-and-add multipliers** like `h * 33 == (h << 5) + h` (djb2) came from CPUs with slow multiplication. On current CPUs a 32/64-bit multiply takes only a few cycles, so this matters little.

Primes closest to `(2^N - 1) × constant`, for reference (checked by computation):

| Constant | 8-bit | 16-bit | 32-bit |
| --- | --- | --- | --- |
| Golden ratio conjugate 1/φ = 0.6180339887 | 157 (`0x9d`) | 40499 (`0x9e33`) | 2654435761 (`0x9e3779b1`) |
| 1/e = 0.3678794412 | 97 (`0x61`) | 24109 (`0x5e2d`) | 1580030173 (`0x5e2d58dd`) |
| 1/π = 0.3183098862 | 83 (`0x53`) | 20857 (`0x5179`) | 1367130559 (`0x517cc1bf`) |

`2654435761` is the multiplier Knuth suggests for multiplicative hashing (TAOCP vol. 3). The Fibonacci hashing constant `0x9e3779b9` (section 3) is the nearest *odd* number to `2^32 / φ`, not a prime.

## 6. Command-line tools

```shell
sha256sum file.iso               # SHA-256; compare with the published value
sha256sum -c SHA256SUMS          # verify a list of files
b2sum file.iso                   # BLAKE2b-512
openssl dgst -sha3-256 file.iso  # SHA-3
xxhsum -H3 file.iso              # XXH3 (package xxhash)
```

More in [checksumCmd.md](checksumCmd.md) and [openssl_note.md](openssl_note.md).

## Related notes

+ [checksumCmd.md](checksumCmd.md): Linux checksum commands (`cksum`, `md5sum`, `sha*sum`)
+ [openssl_note.md](openssl_note.md): `openssl dgst` and other OpenSSL commands
+ [Modbus_RTU.md](Modbus_RTU.md): CRC-16/MODBUS, an error-detecting checksum

## Reference

+ Hash function (overview): <https://en.wikipedia.org/wiki/Hash_function>
+ NIST hash functions (SHA-2, SHA-3): <https://csrc.nist.gov/projects/hash-functions>
+ OWASP Password Storage Cheat Sheet: <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>
+ BLAKE3: <https://github.com/BLAKE3-team/BLAKE3>
+ MurmurHash: <https://en.wikipedia.org/wiki/MurmurHash>
+ SMHasher (hash quality tests): <https://github.com/aappleby/smhasher>
+ CityHash: <https://github.com/google/cityhash>
+ FarmHash: <https://github.com/google/farmhash>
+ xxHash: <https://xxhash.com/>
+ FNV: <http://www.isthe.com/chongo/tech/comp/fnv/>
