const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const WARM_RootPath = b.dependency("WAMR", .{}).path("");
    const WARM_IncludePath = b.pathJoin(&.{ WARM_RootPath.getPath(b), "core/iwasm/include" });
    const WARM_corePath = b.pathJoin(&.{ WARM_RootPath.getPath(b), "core" });

    // TODO: https://github.com/ziglang/zig/issues/20630
    const wasmC_bindgen = b.addTranslateC(.{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = .{
            // get absolute path of core/iwasm/include/wasm_c_api.h
            .cwd_relative = b.pathJoin(&.{
                WARM_IncludePath,
                "wasm_c_api.h",
            }),
        },
        .use_clang = true, // TODO: set 'false' use fno-llvm/fno-clang
    });

    const wasmExport_bindgen = b.addTranslateC(.{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = .{
            // get absolute path of core/iwasm/include/wasm_export.h
            .cwd_relative = b.pathJoin(&.{
                WARM_IncludePath,
                "wasm_export.h",
            }),
        },
        .use_clang = true, // TODO: set 'false' use fno-llvm/fno-clang
    });
    const bh_reader_bindgen = b.addTranslateC(.{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = .{
            // get absolute path of core/iwasm/include/wasm_export.h
            .cwd_relative = b.pathJoin(&.{
                WARM_corePath,
                "shared",
                "utils",
                "uncommon",
                "bh_read_file.c",
            }),
        },
        .use_clang = true, // TODO: set 'false' use fno-llvm/fno-clang
    });
    bh_reader_bindgen.addIncludeDir(
        b.pathJoin(&.{
            WARM_corePath,
            "shared",
            "utils",
            "uncommon",
        }),
    );
    bh_reader_bindgen.addIncludeDir(
        b.pathJoin(&.{
            WARM_corePath,
            "shared",
            "utils",
        }),
    );
    bh_reader_bindgen.addIncludeDir(
        b.pathJoin(&.{
            WARM_corePath,
            "shared",
            "platform",
            @tagName(target.result.os.tag),
        }),
    );

    const vmlib = try buildCMake(b, WARM_RootPath);
    wasmExport_bindgen.step.dependOn(&vmlib.step);

    const wamr_module = b.addModule("wamr", .{
        .root_source_file = b.path("src/bindings.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wamr_module.addImport("wasm_export", wasmExport_bindgen.addModule("wasm_export"));
    wamr_module.addImport("wasm_c_api", wasmC_bindgen.addModule("wasm_c_api"));
    wamr_module.addImport("bh_read_file", bh_reader_bindgen.addModule("bh_read_file"));
    wamr_module.addLibraryPath(b.path(".zig-cache"));
    wamr_module.linkSystemLibrary("vmlib", .{
        .use_pkg_config = .no,
    });
    // if (target.query.isNative()) {
    //     wamr_module.linkSystemLibrary("iwasm", .{});
    // } else {
    //     for (llvm_libs) |lib| {
    //         wamr_module.linkSystemLibrary(lib, .{});
    //     }
    // }

    buildTest(b, wamr_module);
}

fn buildCMake(b: *std.Build, dependency: std.Build.LazyPath) !*std.Build.Step.Run {
    const cmake_app = try b.findProgram(&.{"cmake"}, &.{});
    var cmake_config = b.addSystemCommand(&.{cmake_app});
    cmake_config.addArg("-DCMAKE_BUILD_TYPE=MinRelSize");
    cmake_config.addPrefixedDirectoryArg("-S", dependency);
    cmake_config.addPrefixedDirectoryArg("-B", b.path(".zig-cache"));

    const cpu_count = b.fmt("{}", .{std.Thread.getCpuCount() catch 1});

    const cmake_build = b.addSystemCommand(&.{
        cmake_app,
        "--build",
        ".zig-cache",
        "--parallel",
        cpu_count,
    });
    cmake_build.step.dependOn(&cmake_config.step);
    return cmake_build;
}

fn buildTest(b: *std.Build, module: *std.Build.Module) void {
    const lib_unit_tests = b.addTest(.{
        .name = "wamr-test",
        .root_source_file = b.path("src/main.zig"),
        .target = module.resolved_target.?,
        .optimize = module.optimize.?,
    });
    lib_unit_tests.root_module.addImport("wamr", module);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

const llvm_libs = [_][]const u8{
    "LLVMAggressiveInstCombine",
    "LLVMAnalysis",
    "LLVMAsmParser",
    "LLVMAsmPrinter",
    "LLVMBitReader",
    "LLVMBitWriter",
    "LLVMCFGuard",
    "LLVMCodeGen",
    "LLVMCoroutines",
    "LLVMCoverage",
    "LLVMDWARFLinker",
    "LLVMDWP",
    "LLVMDebugInfoCodeView",
    "LLVMDebugInfoDWARF",
    "LLVMDebugInfoGSYM",
    "LLVMDebugInfoMSF",
    "LLVMDebugInfoPDB",
    "LLVMDlltoolDriver",
    "LLVMExecutionEngine",
    "LLVMExtensions",
    "LLVMFileCheck",
    "LLVMFrontendOpenACC",
    "LLVMFrontendOpenMP",
    "LLVMFuzzMutate",
    "LLVMGlobalISel",
    "LLVMIRReader",
    "LLVMInstCombine",
    "LLVMInstrumentation",
    "LLVMInterfaceStub",
    "LLVMInterpreter",
    "LLVMJITLink",
    "LLVMLTO",
    "LLVMLibDriver",
    "LLVMLineEditor",
    "LLVMLinker",
    "LLVMMC",
    "LLVMMCA",
    "LLVMMCDisassembler",
    "LLVMMCJIT",
    "LLVMMCParser",
    "LLVMMIRParser",
    "LLVMObjCARCOpts",
    "LLVMObject",
    "LLVMObjectYAML",
    "LLVMOption",
    "LLVMOrcJIT",
    "LLVMOrcShared",
    "LLVMOrcTargetProcess",
    "LLVMPasses",
    "LLVMProfileData",
    "LLVMRuntimeDyld",
    "LLVMScalarOpts",
    "LLVMSelectionDAG",
    "LLVMSymbolize",
    "LLVMTarget",
    "LLVMTextAPI",
    "LLVMTransformUtils",
    "LLVMVectorize",
    "LLVMX86AsmParser",
    "LLVMX86CodeGen",
    "LLVMX86Desc",
    "LLVMX86Disassembler",
    "LLVMX86Info",
    "LLVMXRay",
    "LLVMipo",
};
