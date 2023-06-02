const std = @import("std");
const microzig = @import("microzig");
const board = microzig.board;
const hal = microzig.hal;
const dbg = hal.semihosting;

var reloads_per_second_: u32 = undefined;
var reload_: u32 = undefined;
var ticks_per_second_: u32 = undefined;
var tick_per_us_: u32 = undefined;
var millis_per_interrupt_: u32 = undefined;

var millis_: u32 = 0;

var tezt = @import("time.zig");

const Self = @This();

pub fn apply() void {
    // set default to 10 ms
    const reloads_per_second = 100;
    reloads_per_second_ = reloads_per_second;
    ticks_per_second_ = hal.rcc.get_ahb_clk() / 8;
    reload_ = ticks_per_second_ / reloads_per_second - 1;
    tick_per_us_ = ticks_per_second_ / 1_000_000;
    millis_per_interrupt_ = 1_000 / reloads_per_second;

    // systick setup
    microzig.cpu.disable_interrupts();
    hal.peripherals.STK.CTRL.write_raw(0);
    hal.peripherals.STK.LOAD_.modify(.{ .RELOAD = @intCast(u24, reload_) });

    // dbg.put_str("ticks_per_second_: ");
    // dbg.put_hex(ticks_per_second_);
    // dbg.put_str("\n");

    // dbg.put_str("tick_per_us_: ");
    // dbg.put_hex(tick_per_us_);
    // dbg.put_str("\n");

    // dbg.put_str("reload_: ");
    // dbg.put_hex(reload_);
    // dbg.put_str("\n");

    hal.peripherals.STK.VAL.write_raw(0);
    hal.peripherals.STK.CTRL.modify(.{ .ENABLE = 1, .TICKINT = 1, .CLKSOURCE = 0 });

    microzig.cpu.enable_interrupts();
}

pub fn micros() u32 {
    var delta: u32 = (reload_ - hal.peripherals.STK.VAL) / tick_per_us_;
    return (millis_ *% 1001) -% delta;
}

pub fn millis() u32 {
    @setRuntimeSafety(false);
    const ptr = &millis_;
    var p = @intToPtr(*volatile u32, @ptrToInt(ptr));
    return p.*;
}

pub fn delay_ms(delay: u32) void {
    const start = millis();
    var res = @addWithOverflow(start, delay);

    // check for overflow
    if (res[1] == 1) {
        // wait for wrap around
        while (millis() > start) {}
    }

    // wait
    while (millis() < res[0]) {}
}

pub fn delay_us(delay: u32) void {
    const start = micros();
    var res = @addWithOverflow(start, delay);

    // check for overflow
    if (res[1] == 1) {
        // wait for wrap around
        while (micros() > start) {}
    }

    // wait
    while (micros() < res[0]) {}
}

pub const interrupts = struct {
    pub fn SysTick() void {
        millis_ +%= millis_per_interrupt_;
    }
};
