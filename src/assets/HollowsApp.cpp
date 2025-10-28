#include <Hollows.h>

namespace Hollows {
	class App : public Hollows::Application{
	public:
		App() {

		}
		~App() {

		}
	};
}

int main()
{
	Hollows::App* App = new Hollows::App();
	App -> Run();
	delete App;
	return 0;
}