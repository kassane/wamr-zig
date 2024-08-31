// 'c' namespace module
pub const c = struct {
    pub const wasm_export = @import("wasm_export");
    pub const wasm_c = @import("wasm_c_api");
};
