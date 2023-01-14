# Infinite source

This repository holds some runnable code for use with [Luxor.jl](https://github.com/JuliaGraphics/Luxor.jl).

It explores a scriping style workflow for making developing sketches as opposed to pixel art. The idea is to work in a 2d 'model space' (in CAD terms) and output figures in 'paper space', with annotations and the like.

We don't know quite what to do with this, but it seems useful. It is perhaps contra-productive to keep the terminology consistent with Luxor.

## LuxorLayout.jl
This file contains a module with the additional functionality that is 'strictly needed'. It might belong as a submodule in Luxor, or another package. Or act as a source for PRs to Luxor.

<details>
  <summary>Click me</summary>
  
  ### Public interface
  1. Foo
  2. Bar
     * Baz
     * Qux

  ### All functions, structured
  ```js
  function logSomething(something) {
    console.log('Something', something);
  }
  ```
</details>


## [Snowblind - whirl](snowblind_whirl.md)

About the limits for canvas size, what can be rendered as bitmap vs vector graphics, and a 'sprite' drawn in 'paper space' but matching coordinates from 'model space'.

## [Test_long_svg_paths](test_long_svg_paths.md)

We like Santana too much perhaps.

## [Test_scale](test_scale.md)

This is mostly about margins in paper space.

## [Test snap](test_snap.md)

Testing the transformations between paper space and model space.

# To download and test on your own

```
cd cd ~/.julia/environments/
git clone https://github.com/hustf/Infinite_source
cd ininite source
```

You may want to delete `Manifest.toml' and 'Project.toml' before starting Julia. You don't need 'LightXML', 'EzXML', 'HTTP', 'Pango_jll', 'Revise', 'InlineStrings', 'Cairo', 'BenchmarkTools' to run these files. 

Install what's asked for when running the files: Luxor, QuadGK, ThreadPools. 

```
julia --project=. --threads=auto
# Windows only requirement:
julia> Pkg.pin(name = "Pango_jll", version = "v1.42.4")
```
