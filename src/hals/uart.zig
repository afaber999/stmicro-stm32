const std = @import("std");
const microzig = @import("microzig");
const board = microzig.board;
const hal = microzig.hal;

pub inline fn put_char(ch: u8) void {
    while (hal.peripherals.USART2.SR.read().TXE != 0b1) {}
    hal.peripherals.USART2.DR.write_raw(ch);
}

pub inline fn has_char() bool {
    return (hal.peripherals.USART2.SR.read().RXNE == 0b1);
}

pub inline fn get_char() u8 {
    return @truncate(u8, hal.peripherals.USART2.DR.raw);
}

pub fn init(baudrate: u32) void {

    // Enable peripheral clocks: GPIOA, USART2.
    hal.peripherals.RCC.APB1ENR.modify(.{
        .USART2EN = 1,
    });
    hal.peripherals.RCC.APB2ENR.modify(.{
        .IOPAEN = 1,
    });

    // pin 2/3 alternate push/pull, max 10 MHz
    hal.peripherals.GPIOA.CRL.modify(.{
        .MODE2 = 0b01,
        .CNF2 = 0b10,
        .MODE3 = 0b00,
        .CNF3 = 0b10,
    });

    // Set the baud rate to 9600.
    const uartdiv = hal.clocks.sw_clk / baudrate;

    hal.peripherals.USART2.BRR.modify(.{
        .DIV_Mantissa = @truncate(u12, uartdiv / 16),
        .DIV_Fraction = @truncate(u4, uartdiv % 16),
    });

    // enable usart, TX and RX
    hal.peripherals.USART2.CR1.modify(.{
        .RE = 1,
        .TE = 1,
        .UE = 1,
    });
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = args;
    _ = format;
    _ = scope;
    _ = level;
    // const level_prefix = comptime "[{}.{:0>6}] " ++ level.asText();
    // const prefix = comptime level_prefix ++ switch (scope) {
    //     .default => ": ",
    //     else => " (" ++ @tagName(scope) ++ "): ",
    // };

    // if (uart_logger) |uart| {
    //     const current_time = time.get_time_since_boot();
    //     const seconds = current_time.to_us() / std.time.us_per_s;
    //     const microseconds = current_time.to_us() % std.time.us_per_s;

    //     uart.print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
    // }
}
