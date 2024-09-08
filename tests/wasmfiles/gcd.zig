const std = @import("std");

export fn gcd(a: u32, b: u32) callconv(.C) u32 {
    return if (b != 0) gcd(b, @mod(a, b)) else a;
}

pub fn main() void {
    _ = std.c.printf("Hello, world! Please call gcd(10, 5) to see the result.\n");
}
