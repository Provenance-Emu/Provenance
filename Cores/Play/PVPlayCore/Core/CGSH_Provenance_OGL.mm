#import "CGSH_Provenance_OGL.h"
#import "AppConfig.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "PVPlayCore.h"
#import <PVLogging/PVLogging.h>

CGSH_Provenance_OGL::CGSH_Provenance_OGL(
	CAEAGLLayer *layer,
	int width,
	int height,
	int res_factor
) : CGSH_OpenGL(true),
	m_layer(layer),
	m_width(width),
	m_height(height),
	m_res_factor(res_factor)
{
 	CGSH_OpenGL::RegisterPreferences();
}

CGSH_Provenance_OGL::~CGSH_Provenance_OGL()
{
}

CGSH_OpenGL::FactoryFunction CGSH_Provenance_OGL::GetFactoryFunction(
	CAEAGLLayer *layer,
	int width,
	int height,
	int res_factor)
{
	return [layer, width, height, res_factor]() { 
		return new CGSH_Provenance_OGL(
 	 	 	layer, width, height, res_factor); 
	};
}

void CGSH_Provenance_OGL::InitializeImpl()
{
 	m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
 	if(![EAGLContext setCurrentContext:m_context])
 	{
        ELOG(@"Failed to set ES context current");
 	 	return;
 	}
 	CreateFramebuffer();
 	{
 	 	PRESENTATION_PARAMS presentationParams;
 	 	presentationParams.mode = PRESENTATION_MODE_FILL;
 	 	presentationParams.windowWidth = m_framebufferWidth;
 	 	presentationParams.windowHeight = m_framebufferHeight;
 	 	SetPresentationParams(presentationParams);
 	}
 	CGSH_OpenGL::InitializeImpl();
}


void CGSH_Provenance_OGL::CreateFramebuffer()
{
	assert(m_defaultFramebuffer == 0);
	glGenFramebuffers(1, &m_defaultFramebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, m_defaultFramebuffer);
	// Create color render buffer and allocate backing store.
	glGenRenderbuffers(1, &m_colorRenderbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, m_colorRenderbuffer);
	[m_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:m_layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &m_framebufferWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &m_framebufferHeight);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, m_colorRenderbuffer);
	CHECKGLERROR();
	if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
	{
        ELOG(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
		assert(false);
	}
	m_presentFramebuffer = m_defaultFramebuffer;
}


void MakeCurrentThreadRealTime();

void CGSH_Provenance_OGL::PresentBackbuffer()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MakeCurrentThreadRealTime();
        [[NSThread currentThread] setName:@"Play.GLES"];
        [[NSThread currentThread] setQualityOfService:NSQualityOfServiceUserInteractive];
    });
    
	glBindRenderbuffer(GL_RENDERBUFFER, m_colorRenderbuffer);
	[m_context presentRenderbuffer:GL_RENDERBUFFER];
}
