include openssl/aes, openssl/crypto, openssl/evp, openssl/rand

AESKey: cover from AES_KEY

EvpMessageDigestContext: cover from EVP_MD_CTX
EvpMessageDigest: cover from EVP_MD

AES_BLOCK_SIZE,
AES_ENCRYPT,
AES_DECRYPT: extern const Int

OPENSSL_VERSION_NUMBER: extern const Long

SSLEAY_VERSION,
SSLEAY_CFLAGS,
SSLEAY_BUILT_ON,
SSLEAY_PLATFORM,
SSLEAY_DIR: extern const Int

AES_set_encrypt_key: extern func (keyData: Octet*, keyLength: Int, aesKey: AESKey*)
AES_set_decrypt_key: extern func (keyData: Octet*, keyLength: Int, aesKey: AESKey*)
AES_cbc_encrypt: extern func (input: const Octet*, output: Octet*, inputLength: SizeT, key: AESKey*, initVector: Octet*, mode: Int)

EVP_MD_CTX_create: extern func -> EvpMessageDigestContext*
EVP_MD_CTX_destroy: extern func (context: EvpMessageDigestContext*)
EVP_DigestInit: extern func (context: EvpMessageDigestContext*, type: EvpMessageDigest*) -> Int
EVP_DigestUpdate: extern func (context: EvpMessageDigestContext*, data: Void*, size: SizeT) -> Int
EVP_DigestFinal: extern func (context: EvpMessageDigestContext*, output: Octet*, OctetsWritten: UInt*) -> Int

EVP_md5: extern func -> EvpMessageDigest*
EVP_sha1: extern func -> EvpMessageDigest*
EVP_sha256: extern func -> EvpMessageDigest*
EVP_sha512: extern func -> EvpMessageDigest*

RAND_bytes: extern func (output: Octet*, length: Int) -> Int
SSLeay: extern func -> Long
SSLeay_version: extern func (type: Int) -> CString
