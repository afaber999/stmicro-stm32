const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;
const dbg = hal.semihosting;

const INTERNAL_CLK = 8_000_000;

var ext_clk: u32 = undefined;

var cpu_clk: u32 = INTERNAL_CLK;
var ahb_clk: u32 = INTERNAL_CLK;
var apb1_clk: u32 = INTERNAL_CLK;
var apb2_clk: u32 = INTERNAL_CLK;
var usb_clk: u32 = undefined;

pub inline fn get_cpu_clk() u32 {
    return cpu_clk;
}
pub inline fn get_ahb_clk() u32 {
    return ahb_clk;
}
pub inline fn get_apb1_clk() u32 {
    return apb1_clk;
}

pub inline fn get_apb2_clk() u32 {
    return apb2_clk;
}

pub fn dbg_show() void {
    dbg.put_str("sw_clk: ");
    dbg.put_hex(cpu_clk);
    dbg.put_str("\n");

    dbg.put_str("ahb_clk: ");
    dbg.put_hex(ahb_clk);
    dbg.put_str("\n");

    dbg.put_str("apb1_clk: ");
    dbg.put_hex(apb1_clk);
    dbg.put_str("\n");

    dbg.put_str("pb2_clk: ");
    dbg.put_hex(apb2_clk);
    dbg.put_str("\n");
}

pub fn update() void {
    // 00: HSI selected as system clock
    // 01: HSE selected as system clock
    // 10: PLL selected as system clock
    // 11: not allowed

    switch (hal.peripherals.RCC.CFGR.read().SWS) {
        0b00 => {
            // HSI
            cpu_clk = INTERNAL_CLK;
        },
        0b01 => {
            // HSE
            cpu_clk = ext_clk;
        },
        0b10 => {
            // PLL
            var pllmul = hal.peripherals.RCC.CFGR.read().PLLMUL;
            var mult = switch (pllmul) {
                0b0000...0b1110 => @intCast(u32, pllmul) + 2,
                0b1111 => 16,
            };

            var shift = hal.peripherals.RCC.CFGR.read().PLLXTPRE;

            switch (hal.peripherals.RCC.CFGR.read().PLLSRC) {
                0 => cpu_clk = std.math.shr(u32, INTERNAL_CLK * mult, 1),
                1 => cpu_clk = std.math.shr(u32, ext_clk * mult, shift),
            }
        },
        0b11 => {
            unreachable();
        },
    }

    var ahb_shifts: u32 = switch (hal.peripherals.RCC.CFGR.read().HPRE) {
        0b0000...0b0111 => 0, // SYSCLK not divided
        0b1000 => 1, // SYSCLK divided by 2
        0b1001 => 2, // SYSCLK divided by 4
        0b1010 => 3, // SYSCLK divided by 8
        0b1011 => 4, // SYSCLK divided by 16
        0b1100 => 6, // SYSCLK divided by 64
        0b1101 => 7, // SYSCLK divided by 128
        0b1110 => 8, // SYSCLK divided by 256
        0b1111 => 9, // SYSCLK divided by 512
    };

    var abp1_shifts: u32 = switch (hal.peripherals.RCC.CFGR.read().PPRE1) {
        0b000...0b011 => 0, // HCLK not divided
        0b100 => 1, // HCLK divided by 2
        0b101 => 2, // HCLK divided by 4
        0b110 => 3, // HCLK divided by 8
        0b111 => 4, // HCLK divided by 16
    };

    var abp2_shifts: u32 = switch (hal.peripherals.RCC.CFGR.read().PPRE2) {
        0b000...0b011 => 0, // HCLK not divided
        0b100 => 1, // HCLK divided by 2
        0b101 => 2, // HCLK divided by 4
        0b110 => 3, // HCLK divided by 8
        0b111 => 4, // HCLK divided by 16
    };

    ahb_clk = std.math.shr(u32, cpu_clk, ahb_shifts);

    apb1_clk = std.math.shr(u32, ahb_clk, abp1_shifts);
    apb2_clk = std.math.shr(u32, ahb_clk, abp2_shifts);

    usb_clk = undefined;
}

// setup clocks
pub fn setup_high_performance(external_clock_freq: u32) void {
    ext_clk = external_clock_freq;
    // Conf clock : 72MHz using HSE 8MHz crystal w/ PLL X 9 (8MHz x 9 = 72MHz)
    // Two wait states, per datasheet
    hal.peripherals.FLASH.ACR.modify(.{ .LATENCY = 2 });

    // APB Low speed prescaler (APB1) max 36 MHz -> prescale APB1 = HCLK/2
    hal.peripherals.RCC.CFGR.modify(.{ .PPRE1 = 0b100 });

    // USBPRE to 1.5 (max 48 Mhz = 72 / 1.5)
    hal.peripherals.RCC.CFGR.modify(.{ .OTGFSPRE = 0b0 });

    // enable HSE clock
    hal.peripherals.RCC.CR.modify(.{ .HSEON = 0b1 });

    // wait for the HSEREADY flag
    while (hal.peripherals.RCC.CR.read().HSERDY != 0b1) {}

    // set PLL source to HSE
    hal.peripherals.RCC.CFGR.modify(.{ .PLLSRC = 0b1 });

    // multiply PLL * 9 -> 72 MHz
    hal.peripherals.RCC.CFGR.modify(.{ .PLLMUL = 0b0111 });

    // enable PLL
    hal.peripherals.RCC.CR.modify(.{ .PLLON = 0b1 });

    // wait for the PLL ready flag
    while (hal.peripherals.RCC.CR.read().PLLRDY != 0b1) {}

    // set clock source to PLL
    hal.peripherals.RCC.CFGR.modify(.{ .SW = 0b10 });

    // wait for the PLL to be CLK
    while (hal.peripherals.RCC.CFGR.read().SWS != 0b10) {}

    // update all clock frequencies
    update();
}
