const std = @import("std");
const runtime_safety = std.debug.runtime_safety;

const microzig = @import("microzig");

pub const peripherals = microzig.chip.peripherals;
pub const RCC = microzig.peripherals.RCC;

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

inline fn set_reg_field(reg: anytype, comptime field_name: anytype, value: anytype) void {
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
        const idr_reg = pin.gpio_port.IDR;
        const reg_value = @field(idr_reg.read(), "IDR" ++ pin.suffix); // TODO extract to getRegField()?
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
        _ = pin;
    }
};


pub fn debug_log(msg: []const u8) void {
    const msg_ptr = @ptrToInt(&msg[0]);

    asm volatile (
        \\mov r0, #0x04
        \\mov r1, %[str]
        \\nop
        \\bkpt #0xAB
        :
        : [str] "r" (msg_ptr),
        : "r0", "r1"
    );
}

pub fn to_hex(val: u8) u8 {
    return if (val < 10) {
        return @as(u8, val) + '0';
    } else {
        return @as(u8, val) - 10 + 'A';
    };
}

pub fn debug_print_hex(value: anytype) void {
    //    debug_print_int(value, 16);
    var buf: [11]u8 = undefined;
    buf[10] = 0;
    buf[2] = '?';

    var idx: u32 = 9;
    var val = value;

    while (idx > 1) : (idx -= 1) {
        buf[idx] = to_hex(@intCast(u8, val % 16));
        val = val / 16;
    }

    buf[1] = 'X';
    buf[0] = '0';
    debug_log(&buf);
}

