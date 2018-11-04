#include <d3d11.h>
#include "hw\pvr\Renderer_if.h"
#include "oslib\oslib.h"

#pragma comment(lib,"d3d11.lib")

struct d3d11 : Renderer
{
	ID3D11Device* dev;
	IDXGISwapChain* swapchain;
	ID3D11DeviceContext* devctx;
	ID3D11RenderTargetView* rtv;

	bool Init()
	{
		HRESULT hr;

		DXGI_SWAP_CHAIN_DESC sd;
		ZeroMemory( &sd, sizeof( sd ) );
		sd.BufferCount = 1;
		sd.BufferDesc.Width = 640;
		sd.BufferDesc.Height = 480;
		sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
		sd.BufferDesc.RefreshRate.Numerator = 60;
		sd.BufferDesc.RefreshRate.Denominator = 1;
		sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
		sd.OutputWindow = (HWND)libPvr_GetRenderTarget();
		sd.SampleDesc.Count = 1;
		sd.SampleDesc.Quality = 0;
		sd.Windowed = TRUE;

		D3D_FEATURE_LEVEL  FeatureLevelsRequested = D3D_FEATURE_LEVEL_10_0;
		UINT               numLevelsRequested = 1;
		D3D_FEATURE_LEVEL  FeatureLevelsSupported;

		if( FAILED (hr = D3D11CreateDeviceAndSwapChain( NULL, 
						D3D_DRIVER_TYPE_HARDWARE, 
						NULL, 
						0,
						&FeatureLevelsRequested, 
						numLevelsRequested, 
						D3D11_SDK_VERSION, 
						&sd, 
						&swapchain, 
						&dev, 
						&FeatureLevelsSupported,
						&devctx )))
		{
			return hr;
		}

		ID3D11Texture2D* pBackBuffer;

		// Get a pointer to the back buffer
		hr = swapchain->GetBuffer( 0, __uuidof( ID3D11Texture2D ), 
									 ( LPVOID* )&pBackBuffer );

		// Create a render-target view
		dev->CreateRenderTargetView( pBackBuffer, NULL, &rtv );

		// Bind the view
		devctx->OMSetRenderTargets( 1, &rtv, NULL );

		D3D11_VIEWPORT vp;
		vp.Width = 640;
		vp.Height = 480;
		vp.MinDepth = 0.0f;
		vp.MaxDepth = 1.0f;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		devctx->RSSetViewports( 1, &vp );

		return true;
	}

	void Resize(int w, int h) { }
	void Term() { }

	bool Process(TA_context* ctx)
	{
		return true;
	}

	bool Render()
	{
		if (!pvrrc.isRTT)
		{
			float col[4]={0,rand()/(float)RAND_MAX,rand()/(float)RAND_MAX,0};
			devctx->ClearRenderTargetView(rtv,col);
		}

		return !pvrrc.isRTT;
	}

	void Present()
	{
		swapchain->Present(0,0);
	}
};


Renderer* rend_D3D11()
{
	return new d3d11();
}