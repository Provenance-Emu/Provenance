// regtest4.cpp - originally written and placed in the public domain by Wei Dai
//                regtest.cpp split into 3 files due to OOM kills by JW
//                in April 2017. A second split occurred in July 2018.

// Local Changes: Header include path

#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include "cryptlib.h"
#include "../externals/include/cryptopp/factory.h"
#include "bench.h"
#include "cpu.h"

#include "dh.h"
#include "nr.h"
#include "rw.h"
#include "../externals/include/cryptopp/rsa.h"
#include "dsa.h"
#include "pssr.h"
#include "esign.h"

// Hashes
#include "md2.h"
#include "md5.h"
#include "sha.h"

// Aggressive stack checking with VS2005 SP1 and above.
#if (_MSC_FULL_VER >= 140050727)
# pragma strict_gs_check (on)
#endif

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

USING_NAMESPACE(CryptoPP)

void RegisterFactories5()
{
	RegisterDefaultFactoryFor<SimpleKeyAgreementDomain, DH>();
	RegisterAsymmetricCipherDefaultFactories<RSAES<OAEP<SHA1> > >("RSA/OAEP-MGF1(SHA-1)");
	RegisterAsymmetricCipherDefaultFactories<DLIES<> >("DLIES(NoCofactorMultiplication, KDF2(SHA-1), XOR, HMAC(SHA-1), DHAES)");
	RegisterSignatureSchemeDefaultFactories<DSA>();
	RegisterSignatureSchemeDefaultFactories<DSA2<SHA224> >();
	RegisterSignatureSchemeDefaultFactories<DSA2<SHA256> >();
	RegisterSignatureSchemeDefaultFactories<DSA2<SHA384> >();
	RegisterSignatureSchemeDefaultFactories<DSA2<SHA512> >();
	RegisterSignatureSchemeDefaultFactories<DSA_RFC6979<SHA1> >();
	RegisterSignatureSchemeDefaultFactories<DSA_RFC6979<SHA224> >();
	RegisterSignatureSchemeDefaultFactories<DSA_RFC6979<SHA256> >();
	RegisterSignatureSchemeDefaultFactories<DSA_RFC6979<SHA384> >();
	RegisterSignatureSchemeDefaultFactories<DSA_RFC6979<SHA512> >();
	RegisterSignatureSchemeDefaultFactories<NR<SHA1> >("NR(1363)/EMSA1(SHA-1)");
	RegisterSignatureSchemeDefaultFactories<GDSA<SHA1> >("DSA-1363/EMSA1(SHA-1)");
	RegisterSignatureSchemeDefaultFactories<RSASS<PKCS1v15, Weak::MD2> >("RSA/PKCS1-1.5(MD2)");
	RegisterSignatureSchemeDefaultFactories<RSASS<PKCS1v15, SHA1> >("RSA/PKCS1-1.5(SHA-1)");
	RegisterSignatureSchemeDefaultFactories<ESIGN<SHA1> >("ESIGN/EMSA5-MGF1(SHA-1)");
	RegisterSignatureSchemeDefaultFactories<RWSS<P1363_EMSA2, SHA1> >("RW/EMSA2(SHA-1)");
	RegisterSignatureSchemeDefaultFactories<RSASS<PSS, SHA1> >("RSA/PSS-MGF1(SHA-1)");
}
