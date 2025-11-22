#pragma once

#include <Core.h>

namespace Hollows {

	class HOLLOWS_API Application {
	public:
			//Initialization point
		void Init();

		//Update Loop
		void Tick();
		Application();
		virtual ~Application();

		void Run();
	};

	// To be defined in CLIENT
	Application* CreateApplication();
}