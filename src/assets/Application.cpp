//#include "engine/include/Engine.h"
    // src/main.cpp
    #include <iostream>

namespace Hollows {
    __declspec(dllimport) void Print();
}
    int main() {

        Hollows::Print();
        //std::cout << "Hello from Premake C++ project!" << std::endl;
        return 0;
    }
