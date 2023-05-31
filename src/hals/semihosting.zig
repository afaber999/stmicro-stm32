pub fn put_str(msg: []const u8) void {
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

pub fn put_hex(value: anytype) void {
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
        buf[idx + 1] = to_hex(@truncate(u8, val % 16));
        val = val / 16;
    }

    put_str(&buf);
}

pub fn put_char(c: u8) void {
    var ch_ptr: *const u8 = &c;
    asm volatile (
        \\mov r0, 03 
        \\mov r1, %[ch]
        \\nop
        \\bkpt #0xAB
        :
        : [ch] "r" (ch_ptr),
        : "r0", "r1"
    );
}
