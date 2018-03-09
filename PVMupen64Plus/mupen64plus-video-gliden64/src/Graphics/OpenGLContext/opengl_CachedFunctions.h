#pragma once
#include <array>
#include <unordered_map>
#include <Graphics/ObjectHandle.h>
#include <Graphics/Parameter.h>
#include "opengl_GLInfo.h"
#include "opengl_Attributes.h"

namespace opengl {

#define CACHED_USE_CACHE1
#define CACHED_USE_CACHE2
#define CACHED_USE_CACHE4

	template<class T>
	class Cached1
	{
	public:
		bool update(T _param)
		{
#ifdef CACHED_USE_CACHE1
			if (_param == m_cached)
				return false;
#endif
			m_cached = _param;
			return true;
		}

		void reset()
		{
			m_cached.reset();
		}

	protected:
		T m_cached;
	};

	template<class T1, class T2>
	class Cached2
	{
	public:
		bool update(T1 _p1, T2 _p2)
		{
#ifdef CACHED_USE_CACHE2
			if (_p1 == m_p1 &&
				_p2 == m_p2)
				return false;
#endif
			m_p1 = _p1;
			m_p2 = _p2;
			return true;
		}

		void reset()
		{
			m_p1.reset();
			m_p2.reset();
		}

	protected:
		T1 m_p1;
		T2 m_p2;
	};

	class Cached4
	{
	public:
		bool update(graphics::Parameter _p1,
			graphics::Parameter _p2,
			graphics::Parameter _p3,
			graphics::Parameter _p4)
		{
#ifdef CACHED_USE_CACHE4
			if (_p1 == m_p1 &&
				_p2 == m_p2 &&
				_p3 == m_p3 &&
				_p4 == m_p4)
			return false;
#endif
			m_p1 = _p1;
			m_p2 = _p2;
			m_p3 = _p3;
			m_p4 = _p4;
			return true;
		}

		void reset()
		{
			m_p1.reset();
			m_p2.reset();
			m_p3.reset();
			m_p4.reset();
		}

	protected:
		graphics::Parameter m_p1, m_p2, m_p3, m_p4;
	};

	class CachedEnable : public Cached1<graphics::Parameter>
	{
	public:
		CachedEnable(graphics::Parameter _parameter);

		void enable(bool _enable);

	private:
		const graphics::Parameter m_parameter;
	};


	template<typename Bind>
	class CachedBind : public Cached2<graphics::Parameter, graphics::ObjectHandle>
	{
	public:
		CachedBind(Bind _bind) : m_bind(_bind) {}

		void bind(graphics::Parameter _target, graphics::ObjectHandle _name) {
			if (update(_target, _name))
				m_bind(GLenum(_target), GLuint(_name));
		}

	private:
		Bind m_bind;
	};
    
    class CachedBindFramebuffer : public Cached2<graphics::Parameter, graphics::ObjectHandle>
    {
    public:
        CachedBindFramebuffer(decltype(GET_GL_FUNCTION(glBindFramebuffer)) _bind) : m_bind(_bind) {}
        
        void bind(graphics::Parameter _target, graphics::ObjectHandle _name) {
#ifdef OS_IOS
            if (m_defaultFramebuffer == graphics::ObjectHandle::null) {
                GLint defaultFramebuffer;
                glGetIntegerv(GL_FRAMEBUFFER_BINDING, &defaultFramebuffer);
                m_defaultFramebuffer = graphics::ObjectHandle(defaultFramebuffer);
            }
            if (_name == graphics::ObjectHandle::null) {
                _name = m_defaultFramebuffer;
            }
#endif
            if (update(_target, _name))
                m_bind(GLenum(_target), GLuint(_name));
        }
        
    private:
        decltype(GET_GL_FUNCTION(glBindFramebuffer)) m_bind;
#ifdef OS_IOS
        graphics::ObjectHandle m_defaultFramebuffer;
#endif
   };

	typedef CachedBind<decltype(GET_GL_FUNCTION(glBindRenderbuffer))> CachedBindRenderbuffer;

	typedef CachedBind<decltype(GET_GL_FUNCTION(glBindBuffer))> CachedBindBuffer;

	class CachedBindTexture : public Cached2<graphics::Parameter, graphics::ObjectHandle>
	{
	public:
		void bind(graphics::Parameter _tmuIndex, graphics::Parameter _target, graphics::ObjectHandle _name);
	};

	class CachedCullFace : public Cached1<graphics::Parameter>
	{
	public:
		void setCullFace(graphics::Parameter _mode);
	};

	class CachedDepthMask : public Cached1<graphics::Parameter>
	{
	public:
		void setDepthMask(bool _enable);
	};

	class CachedDepthCompare : public Cached1<graphics::Parameter>
	{
	public:
		void setDepthCompare(graphics::Parameter m_mode);
	};

	class CachedViewport : public Cached4
	{
	public:
		void setViewport(s32 _x, s32 _y, s32 _width, s32 _height);
	};

	class CachedScissor : public Cached4
	{
	public:
		void setScissor(s32 _x, s32 _y, s32 _width, s32 _height);
	};

	class CachedBlending : public Cached2<graphics::Parameter, graphics::Parameter>
	{
	public:
		void setBlending(graphics::Parameter _sfactor, graphics::Parameter _dfactor);
	};

	class CachedBlendColor : public Cached4
	{
	public:
		void setBlendColor(f32 _red, f32 _green, f32 _blue, f32 _alpha);
	};

	class CachedClearColor : public Cached4
	{
	public:
		void setClearColor(f32 _red, f32 _green, f32 _blue, f32 _alpha);
	};

	class CachedVertexAttribArray {
	public:
		void enableVertexAttribArray(u32 _index, bool _enable);
		void reset();

	private:
		std::array<graphics::Parameter, MaxAttribIndex> m_attribs;
	};

	class CachedUseProgram : public Cached1<graphics::ObjectHandle>
	{
	public:
		void useProgram(graphics::ObjectHandle _program);
	};

	class CachedTextureUnpackAlignment : public Cached1<s32>
	{
	public:
		CachedTextureUnpackAlignment() { m_cached = -1; }
		void setTextureUnpackAlignment(s32 _param);
	};

	/*---------------CachedFunctions-------------*/

	class CachedFunctions
	{
	public:
		CachedFunctions(const GLInfo & _glinfo);
		~CachedFunctions();

		void reset();

		CachedEnable * getCachedEnable(graphics::Parameter _parameter);

		CachedBindTexture * getCachedBindTexture();

		CachedBindFramebuffer * getCachedBindFramebuffer();

		CachedBindRenderbuffer * getCachedBindRenderbuffer();

		CachedBindBuffer * getCachedBindBuffer();

		CachedCullFace * getCachedCullFace();

		CachedDepthMask * getCachedDepthMask();

		CachedDepthCompare * getCachedDepthCompare();

		CachedViewport * getCachedViewport();

		CachedScissor * getCachedScissor();

		CachedBlending * getCachedBlending();

		CachedBlendColor * getCachedBlendColor();

		CachedClearColor * getCachedClearColor();

		CachedVertexAttribArray * getCachedVertexAttribArray();

		CachedUseProgram * getCachedUseProgram();

		CachedTextureUnpackAlignment * getCachedTextureUnpackAlignment();

	private:
		typedef std::unordered_map<u32, CachedEnable> EnableParameters;

		EnableParameters m_enables;
		CachedBindTexture m_bindTexture;
		CachedBindFramebuffer m_bindFramebuffer;
		CachedBindRenderbuffer m_bindRenderbuffer;
		CachedBindBuffer m_bindBuffer;
		CachedCullFace m_cullFace;
		CachedDepthMask m_depthMask;
		CachedDepthCompare m_depthCompare;
		CachedViewport m_viewport;
		CachedScissor m_scissor;
		CachedBlending m_blending;
		CachedBlendColor m_blendColor;
		CachedClearColor m_clearColor;
		CachedVertexAttribArray m_attribArray;
		CachedUseProgram m_useProgram;
		CachedTextureUnpackAlignment m_unpackAlignment;
	};

}
