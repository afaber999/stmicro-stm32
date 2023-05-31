const std = @import("std");
const runtime_safety = std.debug.runtime_safety;

const microzig = @import("microzig");
pub const usb = @import("usb.zig");
pub const uart = @import("uart.zig");
pub const semihosting = @import("semihosting.zig");
pub const peripherals = microzig.chip.peripherals;
pub const rcc = @import("rcc.zig");

// AF how to connect to board?
pub var clocks = rcc.create_clocks(8_000_000);

pub fn parse_pin(comptime spec: []const u8) type {
    const invalid_format_msg = "The given pin '" ++ spec ++ "' has an invalid format. Pins must follow the format \"P{Port}{Pin}\" scheme.";

    if (spec[0] != 'P')
        @compileError(invalid_format_msg);
    if (spec[1] < 'A' or spec[1] > 'H')
        @compileError(invalid_format_msg);

    return struct {
        /// 'A'...'H'
        pub const pin_number: comptime_int = std.fmt.parseInt(u4, spec[2..], 10) catch @compileError(invalid_format_msg);
        pub const gpio_port_name = spec[1..2];
        pub const gpio_port = @field(peripherals, "GPIO" ++ gpio_port_name);
        pub const suffix = std.fmt.comptimePrint("{d}", .{pin_number});
    };
}

pub inline fn set_reg_field(reg: anytype, comptime field_name: anytype, value: anytype) void {
    var temp = reg.read();
    @field(temp, field_name) = value;
    reg.write(temp);
}

pub const gpio = struct {
    pub const State = microzig.core.experimental.gpio.State;

    pub inline fn enable_port(comptime pin: type) void {
        set_reg_field(&peripherals.RCC.APB2ENR, "IOP" ++ pin.gpio_port_name ++ "EN", 0b1);
    }

    pub inline fn set_output(comptime pin: type) void {
        enable_port(pin);
        comptime var rg = switch (pin.pin_number) {
            0...7 => "CRL",
            8...15 => "CRH",
            else => unreachable,
        };
        set_reg_field(&@field(pin.gpio_port, rg), "MODE" ++ pin.suffix, 0b01);
    }

    pub inline fn set_input(comptime pin: type) void {
        enable_port(pin);
        set_reg_field(@field(pin.gpio_port, "MODER"), "MODER" ++ pin.suffix, 0b00);
    }

    pub fn read(comptime pin: type) State {
        const idr_reg = pin.gpio_port.IDR.read();
        const reg_value = @field(idr_reg, "IDR" ++ pin.suffix); // TODO extract to getRegField()?
        return @intToEnum(State, reg_value);
    }

    pub inline fn write(comptime pin: type, state: State) void {
        switch (state) {
            .low => set_reg_field(&pin.gpio_port.BRR, "BR" ++ pin.suffix, 1),
            .high => set_reg_field(&pin.gpio_port.BSRR, "BS" ++ pin.suffix, 1),
        }
        // const val = state.value();
        // set_reg_field(&pin.gpio_port.ODR, "ODR" ++ pin.suffix, val);
    }

    pub fn toggle(comptime pin: type) void {
        switch (read(pin)) {
            State.low => write(pin, State.high),
            State.high => write(pin, State.low),
        }
    }
};
