const std = @import("std");
const microzig = @import("microzig");
const board = microzig.board;
const hal = microzig.hal;
const dbg = hal.semihosting;

// Want to have 1ms precission in our delays, therefore interrupt
// every millsecond
const reloads_per_second_: u32 = 1000;

var reload_: u32 = undefined;
var ticks_per_second_: u32 = undefined;
var tick_per_us_: u32 = undefined;

var millis_: u32 = 0;
var seconds_: u32 = 0;

var tezt = @import("time.zig");

const Self = @This();

pub fn apply() void {
    ticks_per_second_ = hal.rcc.get_ahb_clk() / 8;
    reload_ = ticks_per_second_ / reloads_per_second_ - 1;
    tick_per_us_ = ticks_per_second_ / 1_000_000;

    // systick setup
    microzig.cpu.disable_interrupts();
    hal.peripherals.STK.CTRL.write_raw(0);
    hal.peripherals.STK.LOAD_.modify(.{ .RELOAD = @intCast(u24, reload_) });

    hal.peripherals.STK.VAL.write_raw(0);
    hal.peripherals.STK.CTRL.modify(.{ .ENABLE = 1, .TICKINT = 1, .CLKSOURCE = 0 });

    microzig.cpu.enable_interrupts();
}

pub fn micros() u32 {
    // todo, not interrupt safe?
    @setRuntimeSafety(false);
    var delta: u32 = (reload_ - hal.peripherals.STK.VAL.raw) / tick_per_us_;
    return (millis_ *% 1001) -% delta;
}

pub fn millis() u32 {
    @setRuntimeSafety(false);
    const ptr = &millis_;
    var p = @intToPtr(*volatile u32, @ptrToInt(ptr));
    return p.*;
}

pub fn seconds() u32 {
    @setRuntimeSafety(false);
    const ptr = &seconds_;
    var p = @intToPtr(*volatile u32, @ptrToInt(ptr));
    return p.*;
}

pub fn delay_ms(delay: u32) void {
    var target_time: i32 = @bitCast(i32, millis() +% delay);
    // wait
    while (target_time -% @bitCast(i32, millis()) > 0) {}
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
        millis_ +%= 1;

        if ((millis_ % 1000) == 0) {
            seconds_ +%= 1;
        }
    }
};
