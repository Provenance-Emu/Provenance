#include <assert.h>
#include <unordered_map>
#include <Graphics/Parameters.h>
#include "opengl_GLInfo.h"
#include "opengl_CachedFunctions.h"
#include "opengl_Utils.h"
#include "opengl_TextureManipulationObjectFactory.h"

#ifndef GL_EXT_texture_filter_anisotropic
#define GL_TEXTURE_MAX_ANISOTROPY_EXT     0x84FE
#define GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT 0x84FF
#endif

namespace opengl {

//#define ENABLE_GL_4_5
#define ENABLE_GL_4_2

	/*---------------Create2DTexture-------------*/

	class GenTexture : public Create2DTexture
	{
	public:
		graphics::ObjectHandle createTexture(graphics::Parameter _target) override
		{
			GLuint glName;
			glGenTextures(1, &glName);
			return graphics::ObjectHandle(glName);
		}
	};

	class CreateTexture : public Create2DTexture
	{
	public:
		static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_5
			return (_glinfo.majorVersion > 4) || (_glinfo.majorVersion == 4 && _glinfo.minorVersion >= 5);
#else
			return false;
#endif
		}

		graphics::ObjectHandle createTexture(graphics::Parameter _target) override
		{
			GLuint glName;
			glCreateTextures(GLenum(_target), 1, &glName);
			return graphics::ObjectHandle(glName);
		}
	};

	/*---------------Init2DTexture-------------*/

	class Init2DTexImage : public Init2DTexture
	{
	public:
		Init2DTexImage(CachedBindTexture* _bind) : m_bind(_bind) {}

		void init2DTexture(const graphics::Context::InitTextureParams & _params) override
		{
			if (_params.msaaLevel == 0) {
				m_bind->bind(_params.textureUnitIndex, graphics::textureTarget::TEXTURE_2D, _params.handle);
				glTexImage2D(GL_TEXTURE_2D,
							 _params.mipMapLevel,
							 GLuint(_params.internalFormat),
							 _params.width,
							 _params.height,
							 0,
							 GLenum(_params.format),
							 GLenum(_params.dataType),
							 _params.data);
			} else {
				m_bind->bind(_params.textureUnitIndex, graphics::textureTarget::TEXTURE_2D_MULTISAMPLE, _params.handle);
				glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
										_params.msaaLevel,
										GLenum(_params.internalFormat),
										_params.width,
										_params.height,
										false);
			}
		}

		void reset(graphics::ObjectHandle _deleted) override {
			m_bind->reset();
		}

	private:
		CachedBindTexture* m_bind;
	};

	class Init2DTexStorage : public Init2DTexture
	{
	public:
		static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_2
			return (_glinfo.texStorage);
#else
			return false;
#endif
		}

		Init2DTexStorage(CachedBindTexture* _bind)
			: m_bind(_bind) {}

		void init2DTexture(const graphics::Context::InitTextureParams & _params) override
		{
			if (_params.msaaLevel == 0) {
				m_bind->bind(_params.textureUnitIndex, graphics::textureTarget::TEXTURE_2D, _params.handle);
				if (m_handle != _params.handle) {
					m_handle = _params.handle;
					glTexStorage2D(GL_TEXTURE_2D,
								   _params.mipMapLevels,
								   GLenum(_params.internalFormat),
								   _params.width,
								   _params.height);
				}

				if (_params.data != nullptr) {
					glTexSubImage2D(GL_TEXTURE_2D,
						_params.mipMapLevel,
						0, 0,
						_params.width,
						_params.height,
						GLuint(_params.format),
						GLenum(_params.dataType),
						_params.data);
				}
			}
			else {
				m_bind->bind(_params.textureUnitIndex, graphics::textureTarget::TEXTURE_2D_MULTISAMPLE, _params.handle);
				glTexStorage2DMultisample(
							GL_TEXTURE_2D_MULTISAMPLE,
							_params.msaaLevel,
							GLenum(_params.internalFormat),
							_params.width,
							_params.height,
							GL_FALSE);
			}

		}

		void reset(graphics::ObjectHandle _deleted) override
		{
			m_bind->reset();
			if (m_handle == _deleted)
				m_handle = graphics::ObjectHandle(0);
		}

	private:
		CachedBindTexture* m_bind;
		graphics::ObjectHandle m_handle;
	};

	class Init2DTextureStorage : public Init2DTexture
	{
	public:
		static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_5
			return (_glinfo.majorVersion > 4) || (_glinfo.majorVersion == 4 && _glinfo.minorVersion >= 5);
#else
			return false;
#endif
		}
		void init2DTexture(const graphics::Context::InitTextureParams & _params) override
		{

			if (_params.msaaLevel == 0) {
				if (m_handle != _params.handle) {
					m_handle = _params.handle;
					glTextureStorage2D(GLuint(_params.handle),
								   _params.mipMapLevels,
								   GLenum(_params.internalFormat),
								   _params.width,
								   _params.height);
				}

				if (_params.data != nullptr) {
					glTextureSubImage2D(GLuint(_params.handle),
						_params.mipMapLevel,
						0, 0,
						_params.width,
						_params.height,
						GLuint(_params.format),
						GLenum(_params.dataType),
						_params.data);
				}
			}
			else {
				glTexStorage2DMultisample(GLuint(_params.handle),
										  _params.msaaLevel,
										  GLenum(_params.internalFormat),
										  _params.width,
										  _params.height,
										  GL_FALSE);
			}
		}

		void reset(graphics::ObjectHandle _deleted) override
		{
			if (m_handle == _deleted)
				m_handle = graphics::ObjectHandle(0);
		}

	private:
		graphics::ObjectHandle m_handle;
	};

	/*---------------Update2DTexture-------------*/

	class Update2DTexSubImage : public Update2DTexture
	{
	public:
		Update2DTexSubImage(CachedBindTexture* _bind)
			: m_bind(_bind) {}

		void update2DTexture(const graphics::Context::UpdateTextureDataParams & _params) override
		{
			m_bind->bind(_params.textureUnitIndex, GL_TEXTURE_2D, _params.handle);

			glTexSubImage2D(GL_TEXTURE_2D,
				_params.mipMapLevel,
				_params.x,
				_params.y,
				_params.width,
				_params.height,
				GLuint(_params.format),
				GLenum(_params.dataType),
				_params.data);
		}

	private:
		CachedBindTexture* m_bind;
	};

	class Update2DTextureSubImage : public Update2DTexture
	{
	public:
		static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_5
			return (_glinfo.majorVersion > 4) || (_glinfo.majorVersion == 4 && _glinfo.minorVersion >= 5);
#else
			return false;
#endif
		}

		void update2DTexture(const graphics::Context::UpdateTextureDataParams & _params) override
		{
			glTextureSubImage2D(GLuint(_params.handle),
				_params.mipMapLevel,
				_params.x,
				_params.y,
				_params.width,
				_params.height,
				GLuint(_params.format),
				GLenum(_params.dataType),
				_params.data);
		}
	};

	/*---------------Set2DTextureParameters-------------*/

	class SetTexParameters : public Set2DTextureParameters
	{
	public:
		SetTexParameters(CachedBindTexture* _bind, TextureParams * _texparams, bool _supportMipmapLevel)
			: m_bind(_bind)
			, m_texparams(_texparams)
			, m_supportMipmapLevel(_supportMipmapLevel) {
		}

		void setTextureParameters(const graphics::Context::TexParameters & _parameters) override
		{
			TextureParams::const_iterator iter = m_texparams->find(u32(_parameters.handle));
			m_bind->bind(_parameters.textureUnitIndex, _parameters.target, _parameters.handle);

			const bool iterValid = iter != m_texparams->end();
			const GLenum target(_parameters.target);
			if (_parameters.magFilter.isValid() && !(iterValid && iter->second.magFilter == GLint(_parameters.magFilter))) {
				glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GLint(_parameters.magFilter));
				(*m_texparams)[u32(_parameters.handle)].magFilter = GLint(_parameters.magFilter);
			}
			if (_parameters.minFilter.isValid() && !(iterValid && iter->second.minFilter == GLint(_parameters.minFilter))) {
				glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GLint(_parameters.minFilter));
				(*m_texparams)[u32(_parameters.handle)].minFilter = GLint(_parameters.minFilter);
			}
			if (_parameters.wrapS.isValid() && !(iterValid && iter->second.wrapS == GLint(_parameters.wrapS))) {
				glTexParameteri(target, GL_TEXTURE_WRAP_S, GLint(_parameters.wrapS));
				(*m_texparams)[u32(_parameters.handle)].wrapS = GLint(_parameters.wrapS);
			}
			if (_parameters.wrapT.isValid() && !(iterValid && iter->second.wrapT == GLint(_parameters.wrapT))) {
				glTexParameteri(target, GL_TEXTURE_WRAP_T, GLint(_parameters.wrapT));
				(*m_texparams)[u32(_parameters.handle)].wrapT = GLint(_parameters.wrapT);
			}
			if (m_supportMipmapLevel && _parameters.maxMipmapLevel.isValid() && !(iterValid && iter->second.maxMipmapLevel == GLint(_parameters.maxMipmapLevel))) {
				glTexParameteri(target, GL_TEXTURE_MAX_LEVEL, GLint(_parameters.maxMipmapLevel));
				(*m_texparams)[u32(_parameters.handle)].maxMipmapLevel = GLint(_parameters.maxMipmapLevel);
			}
			if (_parameters.maxAnisotropy.isValid() && !(iterValid && iter->second.maxAnisotropy == GLfloat(_parameters.maxAnisotropy))) {
				glTexParameterf(target, GL_TEXTURE_MAX_ANISOTROPY_EXT, GLfloat(_parameters.maxMipmapLevel));
				(*m_texparams)[u32(_parameters.handle)].maxAnisotropy = GLfloat(_parameters.maxMipmapLevel);
			}
		}

	private:
		CachedBindTexture* m_bind;
		TextureParams* m_texparams;
		bool m_supportMipmapLevel;
	};


	class SetTextureParameters : public Set2DTextureParameters
	{
	public:
		static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_5
			return (_glinfo.majorVersion > 4) || (_glinfo.majorVersion == 4 && _glinfo.minorVersion >= 5);
#else
			return false;
#endif
		}

		SetTextureParameters() {}

		void setTextureParameters(const graphics::Context::TexParameters & _parameters) override
		{
			const u32 handle(_parameters.handle);
			auto it = m_parameters.find(handle);
			// TODO make cacheable
			if (it == m_parameters.end()) {
				auto res = m_parameters.emplace(handle, _parameters);
				if (res.second)
					it = res.first;
			}

			if (_parameters.magFilter.isValid())
				glTextureParameteri(handle, GL_TEXTURE_MAG_FILTER, GLint(_parameters.magFilter));
			if (_parameters.minFilter.isValid())
				glTextureParameteri(handle, GL_TEXTURE_MIN_FILTER, GLint(_parameters.minFilter));
			if (_parameters.wrapS.isValid())
				glTextureParameteri(handle, GL_TEXTURE_WRAP_S, GLint(_parameters.wrapS));
			if (_parameters.wrapT.isValid())
				glTextureParameteri(handle, GL_TEXTURE_WRAP_T, GLint(_parameters.wrapT));
			if (_parameters.maxMipmapLevel.isValid())
				glTextureParameteri(handle, GL_TEXTURE_MAX_LEVEL, GLint(_parameters.maxMipmapLevel));
			if (_parameters.maxAnisotropy.isValid())
				glTextureParameterf(handle, GL_TEXTURE_MAX_ANISOTROPY_EXT, GLfloat(_parameters.maxAnisotropy));
		}

	private:
		typedef std::unordered_map<u32, graphics::Context::TexParameters> TextureParameters;
		TextureParameters m_parameters;
	};

	/*---------------TextureManipulationObjectFactory-------------*/

	TextureManipulationObjectFactory::TextureManipulationObjectFactory(const GLInfo & _glinfo,
		CachedFunctions & _cachedFunctions)
		: m_glInfo(_glinfo)
		, m_cachedFunctions(_cachedFunctions)
	{
	}

	TextureManipulationObjectFactory::~TextureManipulationObjectFactory()
	{
	}

	Create2DTexture * TextureManipulationObjectFactory::getCreate2DTexture() const
	{
		if (CreateTexture::Check(m_glInfo))
			return new CreateTexture;

		return new GenTexture;
	}

	Init2DTexture * TextureManipulationObjectFactory::getInit2DTexture() const
	{
		if (Init2DTextureStorage::Check(m_glInfo))
			return new Init2DTextureStorage;

		if (Init2DTexStorage::Check(m_glInfo))
			return new Init2DTexStorage(m_cachedFunctions.getCachedBindTexture());

		return new Init2DTexImage(m_cachedFunctions.getCachedBindTexture());
	}

	Update2DTexture * TextureManipulationObjectFactory::getUpdate2DTexture() const
	{
		if (Update2DTextureSubImage::Check(m_glInfo))
			return new Update2DTextureSubImage;

		return new Update2DTexSubImage(m_cachedFunctions.getCachedBindTexture());
	}

	Set2DTextureParameters * TextureManipulationObjectFactory::getSet2DTextureParameters() const
	{
		if (SetTextureParameters::Check(m_glInfo))
			return new SetTextureParameters;

		return new SetTexParameters(m_cachedFunctions.getCachedBindTexture(), m_cachedFunctions.getTexParams(), !m_glInfo.isGLES2);
	}

}
