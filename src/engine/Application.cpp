#include <Application.h>

//#include <diligent>

using namespace Diligent;

//RefCntAutoPtr<IEngineFactory> pFactory;


namespace Hollows {
    Application::Application() {

    }
    Application::~Application() {

    }


void window() {
    SDL_Init(SDL_INIT_VIDEO);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    SDL_Window* window = SDL_CreateWindow("SDL3 is ON, Bitches",
        800, 600, SDL_WINDOW_RESIZABLE);

    SDL_GLContext gl_context = SDL_GL_CreateContext(window);
    SDL_GL_MakeCurrent(window, gl_context);
    

	//L_PropertiesID props = SDL_GetWindowProperties(window);

	//void* hwind_void = SDL_GetPointerProperty(props, "SDL_PROP_WINDOW");

    bool running = true;
    SDL_Event e;
    while (running) {
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_EVENT_QUIT)
                running = false;
        }
    }

    SDL_DestroyWindow(window);
    SDL_Quit();
}





//THE  FUNCTION THAT MATTERS
    void Application::Run() {
        window();
/*        while (true) {
            
        }
        */

    }
}