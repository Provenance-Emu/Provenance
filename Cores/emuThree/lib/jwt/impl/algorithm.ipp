/*
Copyright (c) 2017 Arun Muralidharan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

#ifndef CPP_JWT_ALGORITHM_IPP
#define CPP_JWT_ALGORITHM_IPP

namespace jwt {

template <typename Hasher>
verify_result_t HMACSign<Hasher>::verify(
    const jwt::string_view key,
    const jwt::string_view head,
    const jwt::string_view jwt_sign)
{
  std::error_code ec{};

  unsigned char enc_buf[EVP_MAX_MD_SIZE];
  uint32_t enc_buf_len = 0;

  unsigned char* res = HMAC(Hasher{}(),
                            key.data(),
                            static_cast<int>(key.length()),
                            reinterpret_cast<const unsigned char*>(head.data()),
                            head.length(),
                            enc_buf,
                            &enc_buf_len);
  if (!res) {
    ec = AlgorithmErrc::VerificationErr;
    return {false, ec};
  }
  if (enc_buf_len == 0) {
    ec = AlgorithmErrc::VerificationErr;
    return {false, ec};
  }

  std::string b64_enc_str = jwt::base64_encode((const char*)&enc_buf[0], enc_buf_len);

  if (!b64_enc_str.length()) {
    ec = AlgorithmErrc::VerificationErr;
    return {false, ec};
  }

  // Make the base64 string url safe
  auto new_len = jwt::base64_uri_encode(&b64_enc_str[0], b64_enc_str.length());
  b64_enc_str.resize(new_len);

  bool ret = (jwt::string_view{b64_enc_str} == jwt_sign);

  return { ret, ec };
}


template <typename Hasher>
verify_result_t PEMSign<Hasher>::verify(
    const jwt::string_view key,
    const jwt::string_view head,
    const jwt::string_view jwt_sign)
{
  std::error_code ec{};
  std::string dec_sig = base64_uri_decode(jwt_sign.data(), jwt_sign.length());

  BIO_uptr bufkey{
      BIO_new_mem_buf((void*)key.data(), static_cast<int>(key.length())),
      bio_deletor};

  if (!bufkey) {
    throw MemoryAllocationException("BIO_new_mem_buf failed");
  }

  EC_PKEY_uptr pkey{
    PEM_read_bio_PUBKEY(bufkey.get(), nullptr, nullptr, nullptr),
    ev_pkey_deletor};

  if (!pkey) {
    ec = AlgorithmErrc::InvalidKeyErr;
    return { false, ec };
  }

  int pkey_type = EVP_PKEY_id(pkey.get());

  if (pkey_type != Hasher::type) {
    ec = AlgorithmErrc::VerificationErr;
    return { false, ec };
  }

  //Convert EC signature back to ASN1
  if (Hasher::type == EVP_PKEY_EC) {
    EC_SIG_uptr ec_sig{ECDSA_SIG_new(), ec_sig_deletor};
    if (!ec_sig) {
      throw MemoryAllocationException("ECDSA_SIG_new failed");
    }

    //Get the actual ec_key
    EC_KEY_uptr ec_key{EVP_PKEY_get1_EC_KEY(pkey.get()), ec_key_deletor};
    if (!ec_key) {
      throw MemoryAllocationException("EVP_PKEY_get1_EC_KEY failed");
    }

    unsigned int degree = EC_GROUP_get_degree(
        EC_KEY_get0_group(ec_key.get()));
    
    unsigned int bn_len = (degree + 7) / 8;

    if ((bn_len * 2) != dec_sig.length()) {
      ec = AlgorithmErrc::VerificationErr;
      return { false, ec };
    }

    BIGNUM* ec_sig_r = BN_bin2bn((unsigned char*)dec_sig.data(), bn_len, nullptr);
    BIGNUM* ec_sig_s = BN_bin2bn((unsigned char*)dec_sig.data() + bn_len, bn_len, nullptr);

    if (!ec_sig_r || !ec_sig_s) {
      ec = AlgorithmErrc::VerificationErr;
      return { false, ec };
    }

    ECDSA_SIG_set0(ec_sig.get(), ec_sig_r, ec_sig_s);

    size_t nlen = i2d_ECDSA_SIG(ec_sig.get(), nullptr);
    dec_sig.resize(nlen);

    auto data = reinterpret_cast<unsigned char*>(&dec_sig[0]);
    nlen = i2d_ECDSA_SIG(ec_sig.get(), &data);

    if (nlen == 0) {
      ec = AlgorithmErrc::VerificationErr;
      return { false, ec };
    }
  }

  EVP_MDCTX_uptr mdctx_ptr{EVP_MD_CTX_create(), evp_md_ctx_deletor};
  if (!mdctx_ptr) {
    throw MemoryAllocationException("EVP_MD_CTX_create failed");
  }

  if (EVP_DigestVerifyInit(
        mdctx_ptr.get(), nullptr, Hasher{}(), nullptr, pkey.get()) != 1) {
    ec = AlgorithmErrc::VerificationErr;
    return { false, ec };
  }

  if (EVP_DigestVerifyUpdate(mdctx_ptr.get(), head.data(), head.length()) != 1) {
    ec = AlgorithmErrc::VerificationErr;
    return { false, ec };
  }

  if (EVP_DigestVerifyFinal(
        mdctx_ptr.get(), (unsigned char*)&dec_sig[0], dec_sig.length()) != 1) {
    ec = AlgorithmErrc::VerificationErr;
    return { false, ec };
  }

  return { true, ec };
}

template <typename Hasher>
EVP_PKEY* PEMSign<Hasher>::load_key(
    const jwt::string_view key,
    std::error_code& ec)
{
  ec.clear();

  BIO_uptr bio_ptr{
      BIO_new_mem_buf((void*)key.data(), static_cast<int>(key.length())), 
      bio_deletor};

  if (!bio_ptr) {
    throw MemoryAllocationException("BIO_new_mem_buf failed");
  }

  EVP_PKEY* pkey = PEM_read_bio_PrivateKey(
      bio_ptr.get(), nullptr, nullptr, nullptr);

  if (!pkey) {
    ec = AlgorithmErrc::SigningErr;
    return nullptr;
  }

  auto pkey_type = EVP_PKEY_id(pkey);
  if (pkey_type != Hasher::type) {
    ec = AlgorithmErrc::SigningErr;
    return nullptr;
  }

  return pkey;
}

template <typename Hasher>
std::string PEMSign<Hasher>::evp_digest(
    EVP_PKEY* pkey, 
    const jwt::string_view data, 
    std::error_code& ec)
{
  ec.clear();

  EVP_MDCTX_uptr mdctx_ptr{EVP_MD_CTX_create(), evp_md_ctx_deletor};

  if (!mdctx_ptr) {
    throw MemoryAllocationException("EVP_MD_CTX_create failed");
  }

  //Initialiaze the digest algorithm
  if (EVP_DigestSignInit(
        mdctx_ptr.get(), nullptr, Hasher{}(), nullptr, pkey) != 1) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  //Update the digest with the input data
  if (EVP_DigestSignUpdate(mdctx_ptr.get(), data.data(), data.length()) != 1) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  size_t len = 0;

  if (EVP_DigestSignFinal(mdctx_ptr.get(), nullptr, &len) != 1) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  std::string sign;
  sign.resize(len);

  //Get the signature
  if (EVP_DigestSignFinal(mdctx_ptr.get(), (unsigned char*)&sign[0], &len) != 1) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  return sign;
}

template <typename Hasher>
std::string PEMSign<Hasher>::public_key_ser(
    EVP_PKEY* pkey, 
    jwt::string_view sign, 
    std::error_code& ec)
{
  // Get the EC_KEY representing a public key and
  // (optionaly) an associated private key
  std::string new_sign;
  ec.clear();

  EC_KEY_uptr ec_key{EVP_PKEY_get1_EC_KEY(pkey), ec_key_deletor};

  if (!ec_key) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  uint32_t degree = EC_GROUP_get_degree(EC_KEY_get0_group(ec_key.get()));

  ec_key.reset(nullptr);

  auto char_ptr = &sign[0];

  EC_SIG_uptr ec_sig{d2i_ECDSA_SIG(nullptr,
                                   (const unsigned char**)&char_ptr,
                                   static_cast<long>(sign.length())),
                     ec_sig_deletor};

  if (!ec_sig) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  const BIGNUM* ec_sig_r = nullptr;
  const BIGNUM* ec_sig_s = nullptr;

  ECDSA_SIG_get0(ec_sig.get(), &ec_sig_r, &ec_sig_s);

  int r_len = BN_num_bytes(ec_sig_r);
  int s_len = BN_num_bytes(ec_sig_s);
  int bn_len = static_cast<int>((degree + 7) / 8);

  if ((r_len > bn_len) || (s_len > bn_len)) {
    ec = AlgorithmErrc::SigningErr;
    return {};
  }

  auto buf_len = 2 * bn_len;
  new_sign.resize(buf_len);

  BN_bn2bin(ec_sig_r, (unsigned char*)&new_sign[0] + bn_len - r_len);
  BN_bn2bin(ec_sig_s, (unsigned char*)&new_sign[0] + buf_len - s_len);

  return new_sign;
}

} // END namespace jwt

#endif
