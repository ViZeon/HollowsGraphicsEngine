#pragma once

#include "Core.h"

namespace Hollows {

	class HOLLOWS_API Application {
	public:
		Application();
		virtual ~Application();

		void Run();
	};
}