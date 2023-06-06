const std = @import("std");
const microzig = @import("microzig");
const board = microzig.board;
const hal = microzig.hal;
const time = @import("time.zig");

const UartRegs = microzig.chip.types.USART1;
pub const Self = @This();

pub fn num(comptime n: u2) USART {
    if (n != 1 and n != 2 and n != 2) {
        @compileError("Invalid UART, use 1,2,3");
    }
    return @intToEnum(USART, n - 1);
}

pub const USART = enum(u2) {
    _, // AF figure out why required

    const WriteError = error{};
    const ReadError = error{};
    pub const Writer = std.io.Writer(USART, WriteError, write);
    pub const Reader = std.io.Reader(USART, ReadError, read);

    pub fn writer(usart: USART) Writer {
        return .{ .context = usart };
    }

    pub fn reader(usart: USART) Reader {
        return .{ .context = usart };
    }

    fn get_regs(usart: USART) *volatile UartRegs {
        return switch (@enumToInt(usart)) {
            0 => hal.peripherals.USART1,
            1 => hal.peripherals.USART2,
            2 => hal.peripherals.USART3,
            else => unreachable,
        };
    }

    pub fn apply(usart: USART, baudrate: u32) void {
        const regs = usart.get_regs();

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
        // const uartdiv = switch (@enumToInt(self) {
        //     0 => hal.clocks.apb1_clk / baudrate,
        //     else => hal.clocks.apb1_clk / baudrate,
        // };
        const uartdiv = hal.rcc.get_apb1_clk() / baudrate;

        const dbg = hal.semihosting;

        dbg.put_str("hal.clocks.get_apb1_clk: ");
        dbg.put_hex(hal.rcc.get_apb1_clk());
        dbg.put_str("\n");

        dbg.put_str("uartdiv: ");
        dbg.put_hex(uartdiv);
        dbg.put_str("\n");

        regs.BRR.modify(.{
            .DIV_Mantissa = @truncate(u12, uartdiv / 16),
            .DIV_Fraction = @truncate(u4, uartdiv % 16),
        });

        // enable usart, TX and RX
        regs.CR1.modify(.{
            .RE = 1,
            .TE = 1,
            .UE = 1,
        });
    }

    pub fn put_char(usart: USART, ch: u8) void {
        const regs = usart.get_regs();
        while (regs.SR.read().TXE != 0b1) {}
        regs.DR.write_raw(ch);
    }

    pub fn has_char(usart: USART) bool {
        const regs = usart.get_regs();
        return (regs.SR.read().RXNE == 0b1);
    }

    pub fn get_char(usart: USART) u8 {
        const regs = usart.get_regs();
        return @truncate(u8, regs.DR.raw);
    }

    fn to_hex(usart: USART, val: u8) u8 {
        _ = usart;
        return if (val < 10) {
            return @as(u8, val) + '0';
        } else {
            return @as(u8, val) - 10 + 'A';
        };
    }

    pub fn put_hex(usart: USART, value: anytype) void {
        comptime var prtlen = 0;

        switch (@TypeOf(value)) {
            i32, u32 => prtlen = 8,
            i16, u16 => prtlen = 4,
            u8, i8, bool => prtlen = 2,
            else => {
                @compileLog("Not supported type for put_hex : ", @TypeOf(value));
            },
        }
        var buf: [3 + prtlen]u8 = undefined;
        // create a 0 terminate the string starting with 0x
        buf[0] = '0';
        buf[1] = 'X';
        buf[buf.len - 1] = 0;

        var idx: u32 = prtlen;
        var val = value;

        while (idx > 0) : (idx -= 1) {
            buf[idx + 1] = usart.to_hex(@truncate(u8, val % 16));
            val = val / 16;
        }
        _ = try usart.write(&buf);
    }

    // TODO: implement tx fifo
    pub fn write(usart: USART, payload: []const u8) WriteError!usize {
        for (payload) |byte| {
            usart.put_char(byte);
        }
        return payload.len;
    }

    pub fn read(usart: USART, buffer: []u8) ReadError!usize {
        for (buffer) |*byte| {
            while (!usart.has_char()) {}
            // TODO: error checking
            byte.* = usart.get_char();
        }
        return buffer.len;
    }
};

var usart_logger: ?USART.Writer = null;

pub fn init_logger(usart: USART) void {
    usart_logger = usart.writer();
    usart_logger.?.writeAll("\r\n================ START LOGGER ================\r\n") catch {};
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime "[{}.{}] " ++ level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (usart_logger) |uart| {
        const seconds = hal.systick.seconds();
        const microseconds = hal.systick.micros();
        uart.print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
        //        uart.print(level.asText() ++ " " ++ format ++ "\r\n", args) catch {};
    }
}

pub const interrupts = struct {
    pub fn USART1() void {}
    pub fn USART2() void {}
};
