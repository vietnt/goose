// texture(sampler, P, bias) adds bias to the level of detail before the mip
// is chosen. Each mip of an 8 x 8 texture is one colour: level 0 red, 1
// green, 2 blue, 3 white. Drawn over 8 x 8 pixels (level of detail 0) and
// over 4 x 4 (1), with the nearest mip picked, the bias moves the level read.
import std;
import os;
import gfx;

struct Draw { bias: f32, size: f32, pad 8 }

fn texels(px: u8[:]) -> u8[>..] { str(px[0], ",", px[1], ",", px[2], ",", px[3]) }

fn main() {
    if !gfx::open_headless(8, 8) {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }
    let vs = embed_shader("vert", """
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """);
    let biased = gfx::pipeline(vs, embed_shader("frag", """
        layout(set = 2, binding = 0) uniform sampler2D tex;
        layout(set = 3, binding = 0) uniform Draw { float bias; float size; };
        layout(location = 0) out vec4 result;
        void main() { result = texture(tex, gl_FragCoord.xy / size, bias); }
        """));
    let tex = gfx::texture(gfx::TextureDesc { width: 8, height: 8, mips: 4 });
    let colours: u8[4][4] = [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255], [255, 255, 255, 255]];
    for m in 4 {
        let side = 8 >> m;
        var px: u8[>..] = [];
        for i in side * side { for c in 4 { px.push(colours[m][c]); } }
        gfx::update_texture(tex, gfx::Region { mip: m as i32 }, px);
    }
    let nearest_mip = gfx::sampler(gfx::SamplerDesc { mip_filter: gfx::NEAREST, wrap_u: gfx::CLAMP, wrap_v: gfx::CLAMP });
    for size in [8, 4] {
        let out = gfx::render_target(size, size, gfx::RGBA8);
        for bias in [-1.0, 0.0, 1.0, 2.0] {
            gfx::begin_pass(out, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 });
            gfx::bind(biased);
            gfx::bind_texture(gfx::FRAGMENT, 0, tex, nearest_mip);
            gfx::uniforms(gfx::FRAGMENT, 0, Draw { bias: bias as f32, size: size as f32 });
            gfx::draw(3);
            gfx::end_pass();
            print(size, " x ", size, ", bias ", bias, ": ", texels(gfx::read_pixels(out)));
        }
    }
    gfx::close();
}
