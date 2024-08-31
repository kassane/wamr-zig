const wamr = @import("wamr");

test {
    _ = wamr.c.wasm_export;
    _ = wamr.c.wasm_c;
}
