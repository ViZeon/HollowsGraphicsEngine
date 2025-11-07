#pragma once

#include <Application.h>
//#ifdef HZ_PLATFORM_WINDOWS
extern Hollows::Application* Hollows::CreateApplication();

int main(int argc, char** argv)
{
	auto app = Hollows::CreateApplication();
	//Hollows::App* App = new Hollows::App();
	app -> Run();
	delete app;
	return 0;
}
//#endif