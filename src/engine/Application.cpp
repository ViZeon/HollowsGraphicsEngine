#include <Application.h>

//#include <diligent>

using namespace Diligent;

//RefCntAutoPtr<IEngineFactory> pFactory;


namespace Hollows {
    Application::Application() {

    }
    Application::~Application() {

    }



enum class NativeBackend {
    Win32,
    Cocoa,
    X11,
    Wayland,
    Unknown
};

struct NativeWindow {
    void* handle = nullptr;
    NativeBackend backend = NativeBackend::Unknown;
};

inline NativeWindow GetNativeWindow(SDL_Window* window)
{
    SDL_PropertiesID props = SDL_GetWindowProperties(window);
    NativeWindow out;

    const struct {
        const char* key;
        NativeBackend backend;
    } keys[] = {
        {"SDL_PROP_WINDOW_WIN32_HWND_POINTER",   NativeBackend::Win32},
        {"SDL_PROP_WINDOW_COCOA_WINDOW_POINTER", NativeBackend::Cocoa},
        {"SDL_PROP_WINDOW_X11_WINDOW_POINTER",   NativeBackend::X11},
        {"SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER", NativeBackend::Wayland}
    };

    for (auto& k : keys) {
        void* h = SDL_GetPointerProperty(props, k.key, nullptr);
        if (h) { out.handle = h; out.backend = k.backend; break; }
    }

    return out;
}


void window() {
    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window = SDL_CreateWindow("SDL3 is ON, Bitches",
        800, 600, SDL_WINDOW_RESIZABLE);

	SDL_PropertiesID props = SDL_GetWindowProperties(window);

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