package testing

import vault "../../core/_vault"
import data  "../modules/data"
import wr "../_wrappers"

generate_pixels :: proc(width, height: int) -> []u8 {
    pixels := make([]u8, width * height * 3)
    generate_pixels_inplace(pixels, width, height)
    return pixels
}

generate_pixels_inplace :: proc(pixels: []u8, width, height: int) {
    screen_tex := (^vault.Texture)(data.edit(vault.screen_texture))
    for i in 0 ..< len(pixels) {
        pixels[i] = screen_tex.source.pixels[i]
}
    }

    /*
    for y in 0 ..< height {
        for x in 0 ..< width {
            idx   := (y * width + x) * 3
            pixel := cpu_fragment_shader(wr.Vec2{f32(x), f32(y)})
            pixels[idx + 0] = u8(pixel.x)
            pixels[idx + 1] = u8(pixel.y)
            pixels[idx + 2] = u8(pixel.z)
        }
    }
    
}*/

buffer_render :: proc() {
    start_functions()
    for !(^bool)(data.edit(vault.app_closed))^ {
        update_fuctions()
    }
}