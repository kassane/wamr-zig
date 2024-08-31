# WAMR-zig

### Overview

Based on [WAMR Rust SDK](https://github.com/bytecodealliance/wamr-rust-sdk). It is the wrapper
of [*wasm_export.h*](https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/core/iwasm/include/wasm_export.h) but with Zig style.
It is more convenient to use WAMR in Rust with this crate.


### Requirements

- [Zig](https://ziglang.org/download/) v0.13.0 or master.
- [LLVM libs](https://github.com/llvm/llvm-project/releases) v16.0.0 or master.

#### Core concepts

- *Runtime*. It is the environment that hosts all the wasm modules. Each process has one runtime instance.
- *Module*. It is the compiled .wasm or .aot. It can be loaded into runtime and instantiated into instance.
- *Instance*. It is the running instance of a module. It can be used to call export functions.
- *Function*. It is the exported function.

#### WASI concepts

- *WASIArgs*. It is used to configure the WASI environment.
  - *pre-open*. All files and directories in the list will be opened before the .wasm or .aot loaded.
  - *allowed address*. All ip addresses in the *allowed address* list will be allowed to connect with a socket.
  - *allowed DNS*.


### How to use

- **New project**
```bash
# Create directory
$ mkdir project-name
$ cd project-name
$ zig init
# Add dependency in zon file
$ zig fetch --save=wamr-zig git+https://github.com/wamr-zig/wamr-zig
```
Add in **build.zig**
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wamr_zig = b.dependency("wamr-zig", .{
        .target = target,
        .optimize = optimize,
    });

    // your project
    [exe|lib].root_module.addImport("wamr", wamr_zig.module("wamr"));
}
```