# AMD's Vulkan driver crashes on same-named unused Private globals

Seen 2026-10-16 on Windows 11 with an AMD Radeon 8060S. The driver is AMD's
proprietary one, 26.10.32.01 (LLPC); vulkaninfo gives driverVersion 2.0.395,
apiVersion 1.4.349 and conformance 1.4.3.3, and Windows gives driver
32.0.31032.1003 (2026-07-29, an ASUS OEM build, 26.10.32.01-260727a-202911C).
Not reported to AMD. The release notes of 26.8.1, 26.9.1, 26.9.2 and the
26.10.27.01 Vulkan-extension driver list no fix for pipeline creation or the
LLPC compiler, but their fixed issues name games only, so that does not
show it is unfixed. Lavapipe and Direct3D 12 on the same machine do not
show it.

## What happens

`vkCreateGraphicsPipelines` crashes (0xC0000005, an access violation inside
the driver) when the vertex module and the fragment module each declare an
unused variable in Private storage with the same `OpName`. Both modules
pass `spirv-val --target-env vulkan1.1`, and the Khronos validation layer
reports nothing before the crash.

What decides it, from a bisection of the two stages:

| both stages declare | crashes |
|---|---|
| the same name, unused in both | yes, with or without a depth target |
| the same name, unused, different initializers | yes |
| different names, the same initializer | no |
| the global in one stage only | no |
| the same name, read by both stages | no |

The two modules of a crashing and a passing pair differ only in that
global's `OpName` and initializer.

Before 923f5da the shader compiler (cute_spirv) declared every module-scope
GLSL global, a `const` included, as an `OpVariable` in Private storage with
its `OpName`, used or not. A file of consts that both stages of a pipeline
include, as Rome_goose's `frame.glsl` with its five `*_EPS_Z` depth
offsets, then gave every scene pipeline the crashing pair, and Rome_goose
crashed at its first scene bind on Vulkan.

## Reproducing it

The pair, as GLSL:

```glsl
// vertex
#version 450
const float WATER_EPS_Z = 0.25e-6;
void main() {
    vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
```

```glsl
// fragment
#version 450
const float WATER_EPS_Z = 0.25e-6;
layout(location = 0) out vec4 c;
void main() { c = vec4(0.25, 0.5, 0.75, 1.0); }
```

Compiled by Goose v2026.1 or `v2026.1-rome.1`, the fragment module is
SPIR-V 1.3:

```
               OpCapability Shader
          %1 = OpExtInstImport "GLSL.std.450"
               OpMemoryModel Logical GLSL450
               OpEntryPoint Fragment %11 "main" %5 %9
               OpExecutionMode %11 OriginUpperLeft
               OpName %5 "gl_FragCoord"
               OpName %8 "WATER_EPS_Z"
               OpName %9 "c"
               OpName %11 "main"
               OpDecorate %5 BuiltIn FragCoord
               OpDecorate %9 Location 0
          %3 = OpTypeFloat 32
          %2 = OpTypeVector %3 4
          %4 = OpTypePointer Input %2
          %5 = OpVariable %4 Input
          %6 = OpConstant %3 2.49999999e-07
          %7 = OpTypePointer Private %3
          %8 = OpVariable %7 Private %6
         %10 = OpTypePointer Output %2
          %9 = OpVariable %10 Output
         %12 = OpTypeVoid
         %13 = OpTypeFunction %12
         %14 = OpConstant %3 0.25
         %15 = OpConstant %3 0.5
         %16 = OpConstant %3 0.75
         %17 = OpConstant %3 1
         %11 = OpFunction %12 None %13
         %19 = OpLabel
         %18 = OpCompositeConstruct %2 %14 %15 %16 %17
               OpStore %9 %18
               OpReturn
               OpFunctionEnd
```

and the vertex module carries the same `%WATER_EPS_Z = OpVariable
%_ptr_Private_float Private %float_2_49999999en07` with its `OpName`.

As a Goose program, run with `SDL_GPU_DRIVER=vulkan` and a compiler from
before 923f5da (the pipeline is made at its first bind, where the crash
is):

```goose
import gfx from "github.com/vietnt/goose_gfx@cde02033be8222e4885e857532c047bf6ee40d8e";
import std;
import os;

fn main() {
    guard gfx::open_headless(64, 64) else { write_stderr(str("gfx: ", gfx::error(), "\n")); return; }
    let p = gfx::pipeline(embed_shader("vert", """
        const float WATER_EPS_Z = 0.25e-6;
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """), embed_shader("frag", """
        const float WATER_EPS_Z = 0.25e-6;
        layout(location = 0) out vec4 c;
        void main() { c = vec4(0.25, 0.5, 0.75, 1.0); }
        """));
    let target = gfx::render_target(64, 64, gfx::RGBA8);
    gfx::begin_pass(target, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    gfx::bind(p);
    gfx::draw(3);
    gfx::end_pass();
    let px = gfx::read_pixels(target);
    print("drawn: ", px[0], ",", px[1], ",", px[2], ",", px[3]);
    gfx::close();
}
```

On the driver above, built by Goose v2026.1, it exits with 0xC0000005
(-1073741819) at `gfx::bind` and prints nothing. Renaming the fragment
stage's const to `WATER_EPS_Y` makes the same compiler's build print
`drawn: 64,128,191,255`, as `v2026.1-rome.2` does unchanged.

## What the compiler does

Since 923f5da (in `v2026.1-rome.2`), a Private global's `OpVariable` and
`OpName` are emitted at its first reference, so a module declares only the
Private globals it reads. The pair above then holds no Private variable at
all and creates on that driver; Rome_goose renders there with its
`frame.glsl` unchanged. Two globals of one name that both stages read are
still declared in both, which the bisection found does not crash.
