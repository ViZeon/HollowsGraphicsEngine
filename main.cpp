#include "engine/include/Engine.h"
#include "modules/graphics/include/Graphics.h"

int main() {
    Engine engine;
    Graphics graphics;
    engine.run();
    graphics.render();
    return 0;
}