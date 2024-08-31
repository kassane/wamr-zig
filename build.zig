const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wamrPath = b.dependency("WAMR", .{}).path("core/iwasm/include");

    const wamr_module = b.addModule("wamr", .{
        .root_source_file = b.path("src/bindings.zig"),
        .target = target,
        .optimize = optimize,
    });
    wamr_module.addIncludePath(wamrPath);
    for (llvm_libs) |name| {
        wamr_module.linkSystemLibrary(name, .{});
    }
    wamr_module.link_libc = true;

    buildTest(b, wamr_module);
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
