from conan import ConanFile

class HollowsGraphicsEngineConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "PremakeDeps"
    
    def requirements(self):
        self.requires("bgfx/cci.20230216")
        self.requires("sdl/3.1.6")
        self.requires("glm/cci.20230113")
        self.requires("assimp/5.4.3")
        self.requires("openimageio/2.5.16.0")
        self.requires("spdlog/1.14.1")
    
    def configure(self):
        self.options["bgfx"].shared = False
        self.options["sdl"].shared = False
        self.options["assimp"].shared = False
        self.options["openimageio"].shared = False
        self.options["spdlog"].shared = False
    
    def layout(self):
        self.folders.generators = "./vendor/lib"