#include <Application.h>
#include <SDL3/SDL.h>
#include <diligent>

namespace Hollows {
    Application::Application() {

    }
    Application::~Application() {

    }




void window() {
    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window = SDL_CreateWindow("SDL3 is ON, Bitches",
        800, 600, SDL_WINDOW_RESIZABLE);

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

    void Application::Run() {
        window();
/*        while (true) {
            
        }
        */

    }
}