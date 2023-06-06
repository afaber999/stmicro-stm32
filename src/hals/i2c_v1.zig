const std = @import("std");
const microzig = @import("microzig");
const board = microzig.board;
const hal = microzig.hal;
const time = @import("time.zig");
const peripherals = microzig.chip.peripherals;

const UartRegs = microzig.chip.types.USART1;
pub const Self = @This();

pub fn num(n: u2) I2C {
    return @intToEnum(I2C, n);
}

pub const I2C = enum(u2) {
    _, // AF figure out why required

    fn get_regs(i2c: I2C) *volatile UartRegs {
        return switch (@enumToInt(i2c)) {
            0 => hal.peripherals.I2C1,
            1 => hal.peripherals.I2C2,
            else => unreachable,
        };
    }

    fn get_scl(i2c: I2C) type {
        return switch (@enumToInt(i2c)) {
            0 => hal.parse_pin("PB10"),
            1 => hal.parse_pin("PB10"),
            else => unreachable,
        };
    }

    fn get_sda(i2c: I2C) type {
        return switch (@enumToInt(i2c)) {
            0 => hal.parse_pin("PB11"),
            1 => hal.parse_pin("PB11"),
            else => unreachable,
        };
    }

    pub fn enable(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CR1.modify(.{ .PE = 1 });
    }

    // Set the peripheral clock frequency: 2MHz to 36MHz (the APB frequency). Note
    // that this is <b> not </b> the I2C bus clock. This is set in conjunction with
    // the Clock Control register to generate the Master bus clock
    pub fn set_clock_frequency(i2c: I2C, bus_frequency_mhz: u6) void {
        if (bus_frequency_mhz < 2 or bus_frequency_mhz > 50) {
            return error.InvalidBusFrequency;
        }

        // .FREQ is set to the bus frequency in Mhz
        const regs = i2c.get_regs();
        regs.CR2.modify(.{ .FREQ = bus_frequency_mhz });
    }

    pub fn send_data(i2c: I2C, data: u8) void {
        const regs = i2c.get_regs();
        regs.DR.raw = data;
    }

    pub fn set_fast_mode(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CCR.modify(.{ .FS = 0b1 });
    }

    pub fn set_standard_mode(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CCR.modify(.{ .FS = 0b0 });
    }

    // Set the maximum rise time on the bus according to the I2C specification, as 1
    // more than the specified rise time in peripheral clock cycles. This is a 6 bit
    // number.
    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    // @param[in] trise Unsigned int16. Rise Time Setting 0...63.

    pub fn set_trise(i2c: I2C, trise: u6) void {
        // Trise is bus frequency in Mhz + 1
        const regs = i2c.get_regs();
        regs.TRISE.modify(trise);
    }

    // /** @brief I2C Send the 7-bit Slave Address.
    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    // @param[in] slave Unsigned int16. Slave address 0...1023.
    // @param[in] readwrite Unsigned int8. Single bit to instruct slave to receive or
    // send @ref i2c_rw.

    pub fn send_7bit_address(i2c: I2C, slave: u7, write: bool) void {
        const val = (slave << 1) | @boolToInt(write);
        i2c.send_data(val);
    }

    // @brief I2C Get Data.
    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    pub fn get_data(i2c: I2C) void {
        const regs = i2c.get_regs();
        return regs.DR.read() & 0xff;
    }

    // @brief I2C Enable Interrupt

    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    // @param[in] interrupt Unsigned int32. Interrupt to enable.
    // pub fn enable_interrupt(i2c : I2C, uint32_t interrupt)
    // {
    //     I2C_CR2(i2c) |= interrupt;
    // }

    // brief I2C Enable ACK
    // Enables acking of own 7/10 bit address
    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    pub fn enable_ack(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CR1.modify(.{ .ACK = 0b1 });
    }

    // brief I2C Disable ACK
    // Disables acking of own 7/10 bit address
    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    pub fn disable_ack(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CR1.modify(.{ .ACK = 0b0 });
    }

    // Causes the I2C controller to NACK the reception of the next byte
    // @param[in] i2c Unsigned int32. I2C register base address @ref i2c_reg_base.
    pub fn nack_next(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CR1.modify(.{ .POS = 0b1 });
    }

    pub fn nack_current(i2c: I2C) void {
        const regs = i2c.get_regs();
        regs.CR1.modify(.{ .POS = 0b0 });
    }

    // pub fn write7_v1(i2c: I2C, addr: u8, data: []const u8) void {
    //     // while ((I2C_SR2(i2c) & I2C_SR2_BUSY)) {
    //     // }

    //     //     i2c.send_start();

    //     //     // Wait for the end of the start condition, master mode selected, and BUSY bit set */
    //     // while ( !( (I2C_SR1(i2c) & I2C_SR1_SB)
    //     // 	&& (I2C_SR2(i2c) & I2C_SR2_MSL)
    //     // 	&& (I2C_SR2(i2c) & I2C_SR2_BUSY) ));

    //     // i2c_send_7bit_address(i2c, addr, I2C_WRITE);

    //     // /* Waiting for address is transferred. */
    //     // while (!(I2C_SR1(i2c) & I2C_SR1_ADDR));

    //     // /* Clearing ADDR condition sequence. */
    //     // (void)I2C_SR2(i2c);

    //     // for (size_t i = 0; i < n; i++) {
    //     // 	i2c_send_data(i2c, data[i]);
    //     // 	while (!(I2C_SR1(i2c) & (I2C_SR1_BTF)));
    //     // }
    // }

    pub fn apply(i2c: I2C, target_speed: usize) void {
        const regs = i2c.get_regs();
        const scl = get_scl(i2c);
        const sda = get_sda(i2c);

        // 1. Enable the I2C CLOCK and GPIO CLOCK
        // enable i2c
        peripherals.RCC.APB1ENR.modify(.{ .I2C2EN = 0b1 });

        // 2. Configure the I2C PINs
        // This takes care of setting them alternate function mode with the correct AF
        hal.gpio.set_output(scl, hal.gpio.OutputMode.alternate_pushpull, hal.gpio.OutputSpeed.output_10MHz);
        hal.gpio.set_output(sda, hal.gpio.OutputMode.alternate_opendrain, hal.gpio.OutputSpeed.output_10MHz);

        // // Activate Pull-up
        // set_reg_field(@field(scl.gpio_port, "PUPDR"), "PUPDR" ++ scl.suffix, 0b01);
        // set_reg_field(@field(sda.gpio_port, "PUPDR"), "PUPDR" ++ sda.suffix, 0b01);

        // 3. Reset the I2C
        regs.CR1.modify(.{ .PE = 0 });
        while (regs.CR1.read().PE == 1) {}

        // 4. Configure I2C timing
        const bus_frequency_hz = 36_000_000;
        const bus_frequency_mhz: u6 = @intCast(u6, @divExact(bus_frequency_hz, 1_000_000));

        // .FREQ is set to the bus frequency in Mhz
        i2c.set_clock_frequency(bus_frequency_mhz);

        switch (target_speed) {
            10_000...100_000 => {
                // CCR is bus_freq / (target_speed * 2). We use floor to avoid exceeding the target speed.
                const ccr = @intCast(u12, @divFloor(bus_frequency_hz, target_speed * 2));
                regs.CCR.modify(.{ .CCR = ccr });
                // Trise is bus frequency in Mhz + 1
                set_trise(bus_frequency_mhz + 1);
            },
            100_001...400_000 => {
                // TODO: handle fast mode
                return error.InvalidSpeed;
            },
            else => return error.InvalidSpeed,
        }

        // 5. Program the I2C_CR1 register to enable the peripheral
        i2c.enable();
    }
};

//     pub const ReadState = struct {
//         address: u7,

//         pub fn start(address: u7) !ReadState {
//             return ReadState{ .address = address };
//         }

//         /// Fails with ReadError if incorrect number of bytes is received.
//         pub fn read_no_eof(self: *ReadState, buffer: []u8) !void {
//             std.debug.assert(buffer.len < 256);

//             // Send start and enable ACK
//             i2c_base.CR1.modify(.{ .START = 1, .ACK = 1 });

//             // Wait for the end of the start condition, master mode selected, and BUSY bit set
//             while ((i2c_base.SR1.read().SB == 0 or
//                 i2c_base.SR2.read().MSL == 0 or
//                 i2c_base.SR2.read().BUSY == 0))
//             {}

//             // Write the address to bits 7..1, bit 0 set to 1 to indicate read operation
//             i2c_base.DR.modify((@intCast(u8, self.address) << 1) | 1);

//             // Wait for address confirmation
//             while (i2c_base.SR1.read().ADDR == 0) {}

//             // Read SR2 to clear address condition
//             _ = i2c_base.SR2.read();

//             for (buffer, 0..) |_, i| {
//                 if (i == buffer.len - 1) {
//                     // Disable ACK
//                     i2c_base.CR1.modify(.{ .ACK = 0 });
//                 }

//                 // Wait for data to be received
//                 while (i2c_base.SR1.read().RxNE == 0) {}

//                 // Read data byte
//                 buffer[i] = i2c_base.DR.read();
//             }
//         }

//         pub fn stop(_: *ReadState) !void {
//             // Communication STOP
//             i2c_base.CR1.modify(.{ .STOP = 1 });
//             while (i2c_base.SR2.read().BUSY == 1) {}
//         }

//         pub fn restart_read(self: *ReadState) !ReadState {
//             return ReadState{ .address = self.address };
//         }
//         pub fn restart_write(self: *ReadState) !WriteState {
//             return WriteState{ .address = self.address };
//         }
//     };

// };

//     return struct {
//         pub const WriteState = struct {
//             address: u7,
//             buffer: [255]u8 = undefined,
//             buffer_size: u8 = 0,

//             pub fn start(address: u7) !WriteState {
//                 return WriteState{ .address = address };
//             }

//             pub fn write_all(self: *WriteState, bytes: []const u8) !void {
//                 std.debug.assert(self.buffer_size < 255);
//                 for (bytes) |b| {
//                     self.buffer[self.buffer_size] = b;
//                     self.buffer_size += 1;
//                     if (self.buffer_size == 255) {
//                         try self.send_buffer();
//                     }
//                 }
//             }

//             fn send_buffer(self: *WriteState) !void {
//                 if (self.buffer_size == 0) @panic("write of 0 bytes not supported");

//                 // Wait for the bus to be free
//                 while (i2c_base.SR2.read().BUSY == 1) {}

//                 // Send start
//                 i2c_base.CR1.modify(.{ .START = 1 });

//                 // Wait for the end of the start condition, master mode selected, and BUSY bit set
//                 while ((i2c_base.SR1.read().SB == 0 or
//                     i2c_base.SR2.read().MSL == 0 or
//                     i2c_base.SR2.read().BUSY == 0))
//                 {}

//                 // Write the address to bits 7..1, bit 0 stays at 0 to indicate write operation
//                 i2c_base.DR.modify(@intCast(u8, self.address) << 1);

//                 // Wait for address confirmation
//                 while (i2c_base.SR1.read().ADDR == 0) {}

//                 // Read SR2 to clear address condition
//                 _ = i2c_base.SR2.read();

//                 for (self.buffer[0..self.buffer_size]) |b| {
//                     // Write data byte
//                     i2c_base.DR.modify(b);
//                     // Wait for transfer finished
//                     while (i2c_base.SR1.read().BTF == 0) {}
//                 }
//                 self.buffer_size = 0;
//             }

//             pub fn stop(self: *WriteState) !void {
//                 try self.send_buffer();
//                 // Communication STOP
//                 i2c_base.CR1.modify(.{ .STOP = 1 });
//                 while (i2c_base.SR2.read().BUSY == 1) {}
//             }

//             pub fn restart_read(self: *WriteState) !ReadState {
//                 try self.send_buffer();
//                 return ReadState{ .address = self.address };
//             }
//             pub fn restart_write(self: *WriteState) !WriteState {
//                 try self.send_buffer();
//                 return WriteState{ .address = self.address };
//             }
//         };

//     };
// }
