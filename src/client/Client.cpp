#include "Application.h"
#include <Hollows.h>

class ClientApp : public Hollows::Application{
public:
	ClientApp() {

	}
	~ClientApp() {

	}
};

Hollows::Application* Hollows::CreateApplication(){
	return new ClientApp();
}