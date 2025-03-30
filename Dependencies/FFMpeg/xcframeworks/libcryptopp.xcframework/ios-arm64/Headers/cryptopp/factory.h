// factory.h - originally written and placed in the public domain by Wei Dai

/// \file factory.h
/// \brief Classes and functions for registering and locating library objects

#ifndef CRYPTOPP_OBJFACT_H
#define CRYPTOPP_OBJFACT_H

#include "cryptlib.h"
#include "misc.h"
#include "stdcpp.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Object factory interface for registering objects
/// \tparam AbstractClass Base class interface of the object
template <class AbstractClass>
class ObjectFactory
{
public:
	virtual ~ObjectFactory () {}
	virtual AbstractClass * CreateObject() const =0;
};

/// \brief Object factory for registering objects
/// \tparam AbstractClass Base class interface of the object
/// \tparam ConcreteClass Class object
template <class AbstractClass, class ConcreteClass>
class DefaultObjectFactory : public ObjectFactory<AbstractClass>
{
public:
	AbstractClass * CreateObject() const
	{
		return new ConcreteClass;
	}
};

/// \brief Object factory registry
/// \tparam AbstractClass Base class interface of the object
/// \tparam instance unique identifier
template <class AbstractClass, int instance=0>
class ObjectFactoryRegistry
{
public:
	class FactoryNotFound : public Exception
	{
	public:
		FactoryNotFound(const char *name) : Exception(OTHER_ERROR, std::string("ObjectFactoryRegistry: could not find factory for algorithm ") + name)  {}
	};

	~ObjectFactoryRegistry()
	{
		for (typename Map::iterator i = m_map.begin(); i != m_map.end(); ++i)
		{
			delete (ObjectFactory<AbstractClass> *)i->second;
			i->second = NULLPTR;
		}
	}

	void RegisterFactory(const std::string &name, ObjectFactory<AbstractClass> *factory)
	{
		m_map[name] = factory;
	}

	const ObjectFactory<AbstractClass> * GetFactory(const char *name) const
	{
		typename Map::const_iterator i = m_map.find(name);
		return i == m_map.end() ? NULLPTR : (ObjectFactory<AbstractClass> *)i->second;
	}

	AbstractClass *CreateObject(const char *name) const
	{
		const ObjectFactory<AbstractClass> *factory = GetFactory(name);
		if (!factory)
			throw FactoryNotFound(name);
		return factory->CreateObject();
	}

	// Return a vector containing the factory names. This is easier than returning an iterator.
	// from Andrew Pitonyak
	std::vector<std::string> GetFactoryNames() const
	{
		std::vector<std::string> names;
		typename Map::const_iterator iter;
		for (iter = m_map.begin(); iter != m_map.end(); ++iter)
			names.push_back(iter->first);
		return names;
	}

	CRYPTOPP_NOINLINE static ObjectFactoryRegistry<AbstractClass, instance> & Registry(CRYPTOPP_NOINLINE_DOTDOTDOT);

private:
	// use void * instead of ObjectFactory<AbstractClass> * to save code size
	typedef std::map<std::string, void *> Map;
	Map m_map;
};

template <class AbstractClass, int instance>
ObjectFactoryRegistry<AbstractClass, instance> & ObjectFactoryRegistry<AbstractClass, instance>::Registry(CRYPTOPP_NOINLINE_DOTDOTDOT)
{
	static ObjectFactoryRegistry<AbstractClass, instance> s_registry;
	return s_registry;
}

/// \brief Object factory registry helper
/// \tparam AbstractClass Base class interface of the object
/// \tparam ConcreteClass Class object
/// \tparam instance unique identifier
template <class AbstractClass, class ConcreteClass, int instance = 0>
struct RegisterDefaultFactoryFor
{
	RegisterDefaultFactoryFor(const char *name=NULLPTR)
	{
		// BCB2006 workaround
		std::string n = name ? std::string(name) : std::string(ConcreteClass::StaticAlgorithmName());
		ObjectFactoryRegistry<AbstractClass, instance>::Registry().
		RegisterFactory(n, new DefaultObjectFactory<AbstractClass, ConcreteClass>);
	}
};

/// \fn RegisterAsymmetricCipherDefaultFactories
/// \brief Register asymmetric ciphers
/// \tparam SchemeClass interface of the object under a scheme
/// \details Schemes include asymmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   signature schemes (registers <tt>SchemeClass::Signer</tt> and <tt>SchemeClass::Verifier</tt>),
///   symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   authenticated symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>), etc.
template <class SchemeClass>
void RegisterAsymmetricCipherDefaultFactories(const char *name=NULLPTR)
{
	RegisterDefaultFactoryFor<PK_Encryptor, typename SchemeClass::Encryptor>((const char *)name);
	RegisterDefaultFactoryFor<PK_Decryptor, typename SchemeClass::Decryptor>((const char *)name);
}

/// \fn RegisterSignatureSchemeDefaultFactories
/// \brief Register signature schemes
/// \tparam SchemeClass interface of the object under a scheme
/// \details Schemes include asymmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   signature schemes (registers <tt>SchemeClass::Signer</tt> and <tt>SchemeClass::Verifier</tt>),
///   symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   authenticated symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>), etc.
template <class SchemeClass>
void RegisterSignatureSchemeDefaultFactories(const char *name=NULLPTR)
{
	RegisterDefaultFactoryFor<PK_Signer, typename SchemeClass::Signer>((const char *)name);
	RegisterDefaultFactoryFor<PK_Verifier, typename SchemeClass::Verifier>((const char *)name);
}

/// \fn RegisterSymmetricCipherDefaultFactories
/// \brief Register symmetric ciphers
/// \tparam SchemeClass interface of the object under a scheme
/// \details Schemes include asymmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   signature schemes (registers <tt>SchemeClass::Signer</tt> and <tt>SchemeClass::Verifier</tt>),
///   symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   authenticated symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>), etc.
template <class SchemeClass>
void RegisterSymmetricCipherDefaultFactories(const char *name=NULLPTR)
{
	RegisterDefaultFactoryFor<SymmetricCipher, typename SchemeClass::Encryption, ENCRYPTION>((const char *)name);
	RegisterDefaultFactoryFor<SymmetricCipher, typename SchemeClass::Decryption, DECRYPTION>((const char *)name);
}

/// \fn RegisterAuthenticatedSymmetricCipherDefaultFactories
/// \brief Register authenticated symmetric ciphers
/// \tparam SchemeClass interface of the object under a scheme
/// \details Schemes include asymmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   signature schemes (registers <tt>SchemeClass::Signer</tt> and <tt>SchemeClass::Verifier</tt>),
///   symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>),
///   authenticated symmetric ciphers (registers <tt>SchemeClass::Encryptor</tt> and <tt>SchemeClass::Decryptor</tt>), etc.
template <class SchemeClass>
void RegisterAuthenticatedSymmetricCipherDefaultFactories(const char *name=NULLPTR)
{
	RegisterDefaultFactoryFor<AuthenticatedSymmetricCipher, typename SchemeClass::Encryption, ENCRYPTION>((const char *)name);
	RegisterDefaultFactoryFor<AuthenticatedSymmetricCipher, typename SchemeClass::Decryption, DECRYPTION>((const char *)name);
}

NAMESPACE_END

#endif
