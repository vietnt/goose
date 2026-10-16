// gl_SampleID: a shader reading it runs once per sample, and sample i of a
// 4x target writes 1 into channel i, so the resolved pixel is a quarter in
// every channel. A target of one sample runs it once, as sample 0.
import std;
import os;
import gfx;

fn main() {
    if !gfx::open_headless(1, 1) {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }
    let vs = embed_shader("vert", """
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """);
    let one_hot = gfx::pipeline(vs, embed_shader("frag", """
        layout(location = 0) out vec4 color;
        void main() {
            color = vec4(gl_SampleID == 0 ? 1.0 : 0.0, gl_SampleID == 1 ? 1.0 : 0.0,
                         gl_SampleID == 2 ? 1.0 : 0.0, gl_SampleID == 3 ? 1.0 : 0.0);
        }
        """));
    let samples = gfx::texture(gfx::TextureDesc { format: gfx::RGBA32F, usage: gfx::COLOR_TARGET,
                                                  width: 1, height: 1, samples: 4 });
    let resolved = gfx::render_target(1, 1, gfx::RGBA32F);
    var pass = gfx::PassDesc { color_value: float4 { 0.0, 0.0, 0.0, 0.0 } };
    pass.color[0] = samples;
    pass.resolve[0] = resolved;
    gfx::begin_pass(pass);
    gfx::bind(one_hot);
    gfx::draw(3);
    gfx::end_pass();
    var c: f32[>..] = [];
    gfx::read_texture(resolved, c);
    print("4 samples, resolved: ", c[0], " ", c[1], " ", c[2], " ", c[3]);
    gfx::begin_pass(resolved, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 });
    gfx::bind(one_hot);
    gfx::draw(3);
    gfx::end_pass();
    var d: f32[>..] = [];
    gfx::read_texture(resolved, d);
    print("1 sample: ", d[0], " ", d[1], " ", d[2], " ", d[3]);
    gfx::close();
}
