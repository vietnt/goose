// gl_FrontFacing follows the pipeline's winding: of a triangle wound
// counter-clockwise over the left pixel and one wound clockwise over the
// right, the left is front-facing (red) by default and the right is once
// clockwise faces are front.
import std;
import os;
import gfx;

fn texels(px: u8[:]) -> u8[>..] {
    str(px[0], ",", px[1], ",", px[2], ",", px[3], " ", px[4], ",", px[5], ",", px[6], ",", px[7])
}

fn main() {
    if !gfx::open_headless(2, 1) {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }
    let vs = embed_shader("vert", """
        const vec2 corners[6] = vec2[6](vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(0.0, 3.0),
                                        vec2(0.0, -1.0), vec2(1.0, 3.0), vec2(1.0, -1.0));
        void main() { gl_Position = vec4(corners[gl_VertexIndex], 0.0, 1.0); }
        """);
    let fs = embed_shader("frag", """
        layout(location = 0) out vec4 color;
        vec4 facing() { return gl_FrontFacing ? vec4(1.0, 0.0, 0.0, 1.0) : vec4(0.0, 1.0, 0.0, 1.0); }
        void main() { color = facing(); }
        """);
    let target = gfx::render_target(2, 1, gfx::RGBA8);
    for clockwise in [false, true] {
        gfx::begin_pass(target, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
        gfx::bind(gfx::pipeline(vs, fs, gfx::PipelineDesc { clockwise: clockwise }));
        gfx::draw(6);
        gfx::end_pass();
        print("clockwise front faces ", clockwise, ": ", texels(gfx::read_pixels(target)));
    }
    gfx::close();
}
