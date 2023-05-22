const std = @import("std");
const runtime_safety = std.debug.runtime_safety;

const micro = @import("microzig");

pub const RCC = micro.peripherals.RCC;
//pub const GPIOA = micro.peripherals.GPIOA;
//pub const GPIOB = micro.peripherals.GPIOB;
//pub const GPIOC = micro.peripherals.GPIOC;

pub fn parse_pin(comptime spec: []const u8) type {
    const invalid_format_msg = "The given pin '" ++ spec ++ "' has an invalid format. Pins must follow the format \"P{Port}{Pin}\" scheme.";

    if (spec[0] != 'P')
        @compileError(invalid_format_msg);
    if (spec[1] < 'A' or spec[1] > 'H')
        @compileError(invalid_format_msg);

    const pin_number: comptime_int = std.fmt.parseInt(u4, spec[2..], 10) catch @compileError(invalid_format_msg);

    return struct {
        /// 'A'...'H'
        const gpio_port_name = spec[1..2];
        const gpio_port = @field(micro.peripherals, "GPIO" ++ gpio_port_name);
        const suffix = std.fmt.comptimePrint("{d}", .{pin_number});
    };
}
