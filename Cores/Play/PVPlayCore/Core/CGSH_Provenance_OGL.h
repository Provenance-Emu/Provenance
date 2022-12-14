#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>
#import "gs/GSH_OpenGL/GSH_OpenGL.h"

class CGSH_Provenance_OGL : public CGSH_OpenGL
{
public:
	CGSH_Provenance_OGL(
		CAEAGLLayer *layer,
 	 	int width,
 	 	int height,
		int res_factor
	);
	virtual ~CGSH_Provenance_OGL();

	static FactoryFunction GetFactoryFunction(
		CAEAGLLayer *layer,
 	 	int width,
 	 	int height,
		int res_factor);

	void InitializeImpl() override;
	void PresentBackbuffer() override;
	void CreateFramebuffer();

	GLuint m_defaultFramebuffer = 0;
	GLuint m_colorRenderbuffer = 0;

	CAEAGLLayer *m_layer = nullptr;
	EAGLContext *m_context = nullptr;

private:
	GLint m_framebufferWidth = 0;
	GLint m_framebufferHeight = 0;

	int m_width = 640;
	int m_height = 480;
	int m_res_factor = 1;
};
