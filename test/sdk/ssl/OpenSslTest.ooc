use sdk
use ssl

expect: func (value: Bool) {
	if (!value)
		exit(1)
}

main: func {
	expect(OPENSSL_VERSION_NUMBER != 0)
	expect(OPENSSL_VERSION_NUMBER == SSLeay())
	
	length := 16
	buffer1: Octet[length]
	buffer2: Octet[length]
	for (i in 0 .. 32) {
		expect(RAND_bytes(buffer1[0]&, length) == 1)
		expect(RAND_bytes(buffer2[0]&, length) == 1)
		outputDifferent := false
		for (b in 0 .. length)
			if (buffer1[b] != buffer2[b]) {
				outputDifferent = true
				break
			}
		expect(outputDifferent)
	}
			
	"encrypt / decrypt (text, AES-256)" println()
	keyLengthBits := 256
	keyLength := keyLengthBits / 8
	encryptedLength := AES_BLOCK_SIZE
	password: Octet[keyLength]
	initVector, initVectorDecrypt: Octet[AES_BLOCK_SIZE]
	plainText := ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']
	expectedCipher := [ 0x51, 0x40, 0xBC, 0x1A, 0x07, 0x3E, 0xC3, 0x6B, 0xEF, 0x1B, 0x01, 0xBC, 0x92, 0xF5, 0x4E, 0xA9 ]
	cipherText: Octet[encryptedLength]
	decipheredText: Octet[plainText length]
	encryptionKey, decryptionKey: AESKey

	memset(initVector[0]&, 0, AES_BLOCK_SIZE)
	memset(initVectorDecrypt[0]&, 0, AES_BLOCK_SIZE)
	memset(password[0]&, 0, keyLength)
	memcpy(password[0]&, c"secretkey", 9)

	AES_set_encrypt_key(password[0]&, keyLengthBits, encryptionKey&)
	AES_cbc_encrypt(plainText data, cipherText[0]&, plainText length, encryptionKey&, initVector[0]&, AES_ENCRYPT)

	for (i in 0 .. expectedCipher length)
		expect(cipherText[i] as Octet == expectedCipher[i] as Octet)

	AES_set_decrypt_key(password[0]&, keyLengthBits, decryptionKey&)
	AES_cbc_encrypt(cipherText[0]&, decipheredText[0]&, expectedCipher length, decryptionKey&, initVectorDecrypt[0]&, AES_DECRYPT)

	for (i in 0 .. plainText length)
		expect(plainText[i] as Octet == decipheredText[i] as Octet)
	
	"encrypt / decrypt (random data)" println()
	keyLengthsToTest := [128, 192, 256]
	for (k in 0 .. keyLengthsToTest length) {
		keyLengthBits := keyLengthsToTest[k]
		keyLength := keyLengthBits / 8
		inputLength := 1024
		encryptedLength := 1024
		password: Octet[keyLength]
		initVector, initVectorDecrypt: Octet[AES_BLOCK_SIZE]
		plainText, decipheredText: Octet[inputLength]
		cipherText: Octet[encryptedLength]
		encryptionKey, decryptionKey: AESKey

		expect(RAND_bytes(password[0]&, keyLength) == 1)
		expect(RAND_bytes(plainText[0]&, inputLength) == 1)
		expect(RAND_bytes(initVector[0]&, AES_BLOCK_SIZE) == 1)
		memcpy(initVectorDecrypt[0]&, initVector[0]&, AES_BLOCK_SIZE)

		AES_set_encrypt_key(password[0]&, keyLengthBits, encryptionKey&)
		AES_cbc_encrypt(plainText[0]&, cipherText[0]&, inputLength, encryptionKey&, initVector[0]&, AES_ENCRYPT)

		isEncrypted := false
		for (i in 0 .. inputLength)
			if (plainText[i] != cipherText[i]) {
				isEncrypted = true
				break
			}
		expect(isEncrypted)

		AES_set_decrypt_key(password[0]&, keyLengthBits, decryptionKey&)
		AES_cbc_encrypt(cipherText[0]&, decipheredText[0]&, encryptedLength, decryptionKey&, initVectorDecrypt[0]&, AES_DECRYPT)

		for (i in 0 .. inputLength)
			if (plainText[i] != decipheredText[i])
				expect(false)
	}
	
	"sha-256" println()
	expectedOutput := [ 0x9c, 0x56, 0xcc, 0x51,
		0xb3, 0x74, 0xc3, 0xba,
		0x18, 0x92, 0x10, 0xd5,
		0xb6, 0xd4, 0xbf, 0x57,
		0x79, 0x0d, 0x35, 0x1c,
		0x96, 0xc4, 0x7c, 0x02,
		0x19, 0x0e, 0xcf, 0x1e,
		0x43, 0x06, 0x35, 0xab ]
	context := EVP_MD_CTX_create()
	expect(EVP_DigestInit(context, EVP_sha256()) == 1)
	expect(EVP_DigestUpdate(context, c"abcdefgh", 8) == 1)
	result: Octet[32]
	outputSize: UInt
	expect(EVP_DigestFinal(context, result[0]&, outputSize&) == 1)
	expect(outputSize == 32)
	for (i in 0 .. outputSize)
		expect(result[i] == expectedOutput[i] as Octet)
	EVP_MD_CTX_destroy(context)
	"Pass" println()
}
