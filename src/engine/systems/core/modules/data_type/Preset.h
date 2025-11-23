#pragma once
#include <Core.h>

class Preset
{
private:
    /* data */
public:
    Preset (Register());
    virtual ~Preset() = default;
    
    virtual void Init();
    virtual void Loop();

    
};