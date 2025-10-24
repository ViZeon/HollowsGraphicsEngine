from conan import ConanFile
from conan.tools.layout import cmake_layout

class MyProject(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    requires = "bgfx/cci.20230216", "glfw/3.4", "gainput/1.0.0", "glm/cci.20230113", "assimp/5.4.3", "openimageio/2.5.16.0", "spdlog/1.14.1"
    generators = "PremakeDeps"
    
    def layout(self):
        cmake_layout(self, src_folder=".", build_folder="dependencies")