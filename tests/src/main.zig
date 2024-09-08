const std = @import("std");
const wamr = @import("wamr").c;
const c = wamr.wasm_export;
// const c_bh = wamr.bh_platform;

pub const WasmRuntime = struct {
    module: c.wasm_module_t,
    module_inst: c.wasm_module_inst_t,
    exec_env: c.wasm_exec_env_t,
    buffer: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, wasm_path: []const u8, wasi_dir: []const u8) !*WasmRuntime {
        var self = try allocator.create(WasmRuntime);
        errdefer allocator.destroy(self);

        self.* = WasmRuntime{
            .module = null,
            .module_inst = null,
            .exec_env = null,
            .buffer = undefined,
            .allocator = allocator,
        };

        var init_args: c.RuntimeInitArgs = std.mem.zeroes(c.RuntimeInitArgs);
        init_args.mem_alloc_type = c.Alloc_With_Pool;
        init_args.mem_alloc_option.pool.heap_buf = &global_heap_buf;
        init_args.mem_alloc_option.pool.heap_size = global_heap_buf.len;

        if (!c.wasm_runtime_full_init(&init_args)) {
            return error.RuntimeInitFailed;
        }

        // var buf_size: u32 = undefined;
        // self.buffer = c_bh.bh_read_file_to_buffer(wasm_path.ptr, &buf_size);
        // if (self.buffer == null) {
        //     return error.FileReadFailed;
        // }
        // buf_size = @intCast(std.mem.len(self.buffer));

        std.debug.print("Attempting to open file: {s}\n", .{wasm_path});

        // Read file using Zig's std lib
        const file = std.fs.cwd().openFile(wasm_path, .{}) catch |err| {
            std.log.err("Failed to open file: {s}, error: {}\n", .{ wasm_path, err });
            return error.FileOpenFailed;
        };
        defer file.close();

        const file_size = file.getEndPos() catch |err| {
            std.log.err("Failed to get file size, error: {}\n", .{err});
            return error.FileReadFailed;
        };

        std.debug.print("File size: {}\n", .{file_size});

        if (file_size == 0) {
            std.log.err("File is empty\n", .{});
            return error.EmptyFile;
        }

        self.buffer = allocator.alloc(u8, file_size) catch |err| {
            std.log.err("Failed to allocate buffer, error: {}\n", .{err});
            return error.MemoryAllocationFailed;
        };
        errdefer allocator.free(self.buffer);

        const bytes_read = file.readAll(self.buffer) catch |err| {
            std.log.err("Failed to read file, error: {}\n", .{err});
            return error.FileReadFailed;
        };

        std.debug.print("Bytes read: {}\n", .{bytes_read});

        if (bytes_read != file_size) {
            std.log.err("Incomplete file read: {} of {} bytes\n", .{ bytes_read, file_size });
            return error.FileReadIncomplete;
        }

        std.debug.print("Attempting to load WASM module. Buffer size: {}\n", .{self.buffer.len});

        const buf_size: u32 = @min(self.buffer.len, 1024 * 1024); //@intCast(self.buffer.len);
        if (!validateWasmFile(self.buffer)) {
            std.log.err("Invalid WASM file format\n", .{});
            return error.InvalidWasmFormat;
        }

        var error_buf: [128]u8 = std.mem.zeroes([128]u8);
        self.module = c.wasm_runtime_load(self.buffer.ptr, buf_size, &error_buf, error_buf.len);
        if (self.module == null) {
            std.debug.print("Buffer size: {}\n", .{self.buffer.len});
            std.log.err("Failed to load WASM module. Error: {s}\n", .{error_buf});
            std.debug.print("First 16 bytes of WASM file: ", .{});
            for (self.buffer[0..@min(16, buf_size)]) |byte| {
                std.debug.print("{x:0>2} ", .{byte});
            }
            std.debug.print("\n", .{});
            return error.ModuleLoadFailed;
        }

        const wasi_dir_ptr: [*c][*c]const u8 = @ptrCast(@alignCast(@constCast(wasi_dir.ptr)));
        _ = c.wasm_runtime_set_wasi_args_ex(self.module, wasi_dir_ptr, 1, null, 0, null, 0, null, 0, 0, 1, 2);

        const stack_size: u32 = 8092;
        const heap_size: u32 = 8092;

        self.module_inst = c.wasm_runtime_instantiate(self.module, stack_size, heap_size, &error_buf, error_buf.len);
        if (self.module_inst == null) {
            return error.ModuleInstantiateFailed;
        }

        self.exec_env = c.wasm_runtime_create_exec_env(self.module_inst, stack_size);
        if (self.exec_env == null) {
            return error.ExecEnvCreateFailed;
        }

        return self;
    }

    pub fn deinit(self: *WasmRuntime) void {
        if (self.exec_env) |env| c.wasm_runtime_destroy_exec_env(env);
        if (self.module_inst) |inst| c.wasm_runtime_deinstantiate(inst);
        if (self.module) |mod| c.wasm_runtime_unload(mod);
        // if (self.buffer) |buf| std.c.free(@ptrCast(@constCast(&buf)));
        self.allocator.free(self.buffer);
        c.wasm_runtime_destroy();
        self.allocator.destroy(self);
    }

    pub fn executeMain(self: *WasmRuntime) !u32 {
        if (c.wasm_application_execute_main(self.module_inst, 0, null)) {
            return c.wasm_runtime_get_wasi_exit_code(self.module_inst);
        } else {
            const exception = c.wasm_runtime_get_exception(self.module_inst);
            std.log.err("WASM execution failed. Exception: {s}\n", .{exception});
            return error.MainExecutionFailed;
        }
    }
    var global_heap_buf: [512 * 1024]u8 = undefined;
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = (@import("builtin").mode == .Debug),
    }){};
    defer {
        if (gpa.detectLeaks()) {
            std.log.err("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <wasm_file_path> <wasi_dir_path>\n", .{args[0]});
        return;
    }

    var runtime = WasmRuntime.init(allocator, args[1], args[2]) catch |err| {
        std.log.err("Failed to initialize WasmRuntime: {}\n", .{err});
        return;
    };
    defer runtime.deinit();

    const result = runtime.executeMain() catch |err| {
        std.log.err("Failed to execute WASM main: {}\n", .{err});
        return;
    };
    std.debug.print("WASM application exited with code: {}\n", .{result});
}

fn validateWasmFile(buffer: []const u8) bool {
    if (buffer.len < 8) return false;
    const magic_number = [_]u8{ 0x00, 0x61, 0x73, 0x6d };
    const version = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    return std.mem.eql(u8, buffer[0..4], &magic_number) and std.mem.eql(u8, buffer[4..8], &version);
}
