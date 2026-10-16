# cute_spirv

`cute_spirv.h` (v1.11) and its dependency `ckit.h`, copied from
[RandyGaul/cute_framework](https://github.com/RandyGaul/cute_framework),
`libraries/cute/`, at commit `5e066a31b0a11e9ac923a2f0b5e4687d57797a10`
(2026-10-13). `cute_spirv.h` last changed there in `a5c53e4a7`.

`cute_spirv.h` compiles a subset of GLSL 450 to SPIR-V and transpiles it to
HLSL (Shader Model 5.1) and MSL, following SDL_GPU's binding conventions. The
compiler uses it to implement `embed_shader`. Both headers are compiled in
`src/shaderc.c`.

Licenses:

* `cute_spirv.h`: choose the zlib license or the public-domain dedication
  (Unlicense). The full text is at the end of the file.
* `ckit.h`: public domain.

## Local changes

`cute_spirv.h` differs from that commit in these, each made so it could also
go to cute_framework, and each with a fixture in `test/gfx/`:

* `gl_FrontFacing` in fragment shaders: SPIR-V `BuiltIn FrontFacing`, HLSL
  `SV_IsFrontFace`, MSL `[[front_facing]]`, WGSL `@builtin(front_facing)`;
  GLSL ES has it. Declared on first use, as `gl_FragDepth` is
  (`gfx_front_facing`).
* `gl_SampleID` in fragment shaders, which makes them run once per sample:
  SPIR-V `BuiltIn SampleId` (flat) with the `SampleRateShading` capability,
  HLSL `SV_SampleIndex`, MSL `[[sample_id]]`, WGSL `@builtin(sample_index)`;
  a compile error for GLSL ES 3.00, which has none (`gfx_sample_id`).
* `textureGather(sampler, P[, comp])` on `sampler2D`, `sampler2DArray` and
  `samplerCube`, with `comp` an integer literal 0 to 3: SPIR-V
  `OpImageGather`, HLSL `GatherRed`/`GatherGreen`/`GatherBlue`/`GatherAlpha`,
  MSL `gather(..., component::x)` to `::w`, WGSL `textureGather`; a compile
  error for GLSL ES 3.00, which has none (`gfx_gather`).
* `textureQueryLod(sampler, P)` in fragment shaders, on every dim but the
  shadow ones: SPIR-V `OpImageQueryLod` (with the `ImageQuery` capability),
  HLSL `CalculateLevelOfDetail` and `CalculateLevelOfDetailUnclamped`, MSL
  `calculate_clamped_lod` and `calculate_unclamped_lod`; a compile error for
  GLSL ES 3.00 and WGSL, which have none (`gfx_query_lod`).

To update, copy both files from a newer cute_framework commit, record that
commit here, and apply the local changes above that it does not have.
