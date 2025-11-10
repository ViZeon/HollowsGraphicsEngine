#include <Application.h>


using namespace Diligent;

Diligent::IEngineFactoryOpenGL* pFactory = Diligent::GetEngineFactoryOpenGL();
Diligent::SwapChainDesc SCDesc;
Diligent::NativeWindow windowHandle;

Diligent::RefCntAutoPtr<Diligent::IRenderDevice>  m_pDevice;
Diligent::RefCntAutoPtr<Diligent::IDeviceContext> m_pImmediateContext;
Diligent::RefCntAutoPtr<Diligent::ISwapChain>     m_pSwapChain;

namespace Hollows {
    Application::Application() {
    }
    Application::~Application() {
    }


void DiligentControl(SDL_Window* sdlWindow) {
    Diligent::EngineGLCreateInfo EngineCI;
    EngineCI.Window = Diligent::NativeWindow{nullptr};
    
    // Don't create swap chain - just device and context
    pFactory->CreateDeviceAndSwapChainGL(
        EngineCI,
        &m_pDevice,
        &m_pImmediateContext,
        Diligent::SwapChainDesc{},
        &m_pSwapChain
    );
    
    if (!m_pDevice || !m_pImmediateContext) {
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Error", "Failed init", sdlWindow);
    }
}

void window() {
    SDL_Init(SDL_INIT_VIDEO);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    SDL_Window* window = SDL_CreateWindow("SDL3 is ON, Bitches",
        800, 600, SDL_WINDOW_RESIZABLE | SDL_WINDOW_OPENGL);
    if (!window) {
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Error", SDL_GetError(), nullptr);
        return;
    }
    
    SDL_PropertiesID props = SDL_GetWindowProperties(window);
    HWND hwnd = (HWND)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL);
    windowHandle.hWnd = hwnd;

    SDL_GLContext gl_context = SDL_GL_CreateContext(window);

    if (!gl_context) {
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Error", SDL_GetError(), window);
        return;
    }

    SDL_GL_MakeCurrent(window, gl_context);

    DiligentControl(window);

    bool running = true;
    SDL_Event e;
    while (running) {
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_EVENT_QUIT)
            running = false;
    }
    
    // Clear using OpenGL directly
    glClearColor(0.0f, 0.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    SDL_GL_SwapWindow(window);
}

    SDL_GL_DestroyContext(gl_context);
    SDL_DestroyWindow(window);
    SDL_Quit();
}

    void Application::Run() {
        window();
    }
}