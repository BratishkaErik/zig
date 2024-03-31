pub const ArchOsAbi = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
    os_ver: ?std.SemanticVersion = null,

    // Minimum glibc version that provides support for the arch/os when ABI is GNU.
    glibc_min: ?std.SemanticVersion = null,
};

pub const available_libcs = [_]ArchOsAbi{
    .{ .arch = .aarch64_be, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 17, .patch = 0 } },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64_be, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .macos, .abi = .none, .os_ver = .{ .major = 11, .minor = 0, .patch = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabi },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabi },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .armeb, .os = .windows, .abi = .gnu },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabi },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .arm, .os = .linux, .abi = .musleabi },
    .{ .arch = .arm, .os = .linux, .abi = .musleabihf },
    .{ .arch = .thumb, .os = .linux, .abi = .gnueabi },
    .{ .arch = .thumb, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabi },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .arm, .os = .windows, .abi = .gnu },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabi },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .x86, .os = .linux, .abi = .gnu },
    .{ .arch = .x86, .os = .linux, .abi = .musl },
    .{ .arch = .x86, .os = .windows, .abi = .gnu },
    .{ .arch = .m68k, .os = .linux, .abi = .gnu },
    .{ .arch = .m68k, .os = .linux, .abi = .musl },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabi64 },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabin32 },
    .{ .arch = .mips64el, .os = .linux, .abi = .musl },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabi64 },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabin32 },
    .{ .arch = .mips64, .os = .linux, .abi = .musl },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnueabi },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .mipsel, .os = .linux, .abi = .musl },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabi },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .mips, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 19, .patch = 0 } },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc64, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabi },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .powerpc, .os = .linux, .abi = .musl },
    .{ .arch = .riscv64, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 27, .patch = 0 } },
    .{ .arch = .riscv64, .os = .linux, .abi = .musl },
    .{ .arch = .s390x, .os = .linux, .abi = .gnu },
    .{ .arch = .s390x, .os = .linux, .abi = .musl },
    .{ .arch = .sparc, .os = .linux, .abi = .gnu },
    .{ .arch = .sparc64, .os = .linux, .abi = .gnu },
    .{ .arch = .wasm32, .os = .freestanding, .abi = .musl },
    .{ .arch = .wasm32, .os = .wasi, .abi = .musl },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnu },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnux32 },
    .{ .arch = .x86_64, .os = .linux, .abi = .musl },
    .{ .arch = .x86_64, .os = .windows, .abi = .gnu },
    .{ .arch = .x86_64, .os = .macos, .abi = .none, .os_ver = .{ .major = 10, .minor = 7, .patch = 0 } },
};

pub fn canBuildLibC(target: std.Target) bool {
    for (available_libcs) |libc| {
        if (target.cpu.arch == libc.arch and target.os.tag == libc.os and target.abi == libc.abi) {
            if (target.os.tag == .macos) {
                const ver = target.os.version_range.semver;
                return ver.min.order(libc.os_ver.?) != .lt;
            }
            // Ensure glibc (aka *-linux-gnu) version is supported
            if (target.isGnuLibC()) {
                const min_glibc_ver = libc.glibc_min orelse return true;
                const target_glibc_ver = target.os.version_range.linux.glibc;
                return target_glibc_ver.order(min_glibc_ver) != .lt;
            }
            return true;
        }
    }
    return false;
}

pub fn muslArchNameHeaders(arch: std.Target.Cpu.Arch) [:0]const u8 {
    return switch (arch) {
        .x86 => return "x86",
        else => muslArchName(arch),
    };
}

pub fn muslArchName(arch: std.Target.Cpu.Arch) [:0]const u8 {
    switch (arch) {
        .aarch64, .aarch64_be => return "aarch64",
        .arm, .armeb, .thumb, .thumbeb => return "arm",
        .x86 => return "i386",
        .mips, .mipsel => return "mips",
        .mips64el, .mips64 => return "mips64",
        .powerpc => return "powerpc",
        .powerpc64, .powerpc64le => return "powerpc64",
        .riscv64 => return "riscv64",
        .s390x => return "s390x",
        .wasm32, .wasm64 => return "wasm",
        .x86_64 => return "x86_64",
        else => unreachable,
    }
}

pub fn zigTargetToLlvmTriple(allocator: std.mem.Allocator, target: std.Target) error{OutOfMemory}![]const u8 {
    var llvm_triple = std.ArrayList(u8).init(allocator);
    errdefer llvm_triple.deinit();

    const llvm_arch = switch (target.cpu.arch) {
        .spu_2 => return error.@"LLVM backend does not support SPU Mark II",
        .x86 => "i386",

        .aarch64,
        .aarch64_32,
        .aarch64_be,
        .amdgcn,
        .amdil,
        .amdil64,
        .arc,
        .arm,
        .armeb,
        .avr,
        .bpfeb,
        .bpfel,
        .csky,
        .dxil,
        .hexagon,
        .hsail,
        .hsail64,
        .kalimba,
        .lanai,
        .le32,
        .le64,
        .loongarch32,
        .loongarch64,
        .m68k,
        .mips,
        .mips64,
        .mips64el,
        .mipsel,
        .msp430,
        .nvptx,
        .nvptx64,
        .powerpc,
        .powerpc64,
        .powerpc64le,
        .powerpcle,
        .r600,
        .renderscript32,
        .renderscript64,
        .riscv32,
        .riscv64,
        .s390x,
        .shave,
        .sparc,
        .sparc64,
        .sparcel,
        .spir,
        .spir64,
        .spirv32,
        .spirv64,
        .tce,
        .tcele,
        .thumb,
        .thumbeb,
        .ve,
        .wasm32,
        .wasm64,
        .x86_64,
        .xcore,
        .xtensa,
        => |tag| @tagName(tag),
    };
    try llvm_triple.appendSlice(llvm_arch);
    try llvm_triple.appendSlice("-unknown-");

    const llvm_os = switch (target.os.tag) {
        .illumos => "solaris",
        .macos => "macosx",
        .uefi => "windows",

        .freestanding,
        .other,
        //
        .glsl450,
        .opencl,
        .plan9,
        .vulkan,
        => "unknown",

        .aix,
        .amdhsa,
        .amdpal,
        .ananas,
        .cloudabi,
        .contiki,
        .cuda,
        .dragonfly,
        .driverkit,
        .elfiamcu,
        .emscripten,
        .freebsd,
        .fuchsia,
        .haiku,
        .hermit,
        .hurd,
        .ios,
        .kfreebsd,
        .linux,
        .liteos,
        .lv2,
        .mesa3d,
        .minix,
        .nacl,
        .netbsd,
        .nvcl,
        .openbsd,
        .ps4,
        .ps5,
        .rtems,
        .shadermodel,
        .tvos,
        .wasi,
        .watchos,
        .windows,
        .zos,
        => |tag| @tagName(tag),
    };
    try llvm_triple.appendSlice(llvm_os);

    if (target.os.tag.isDarwin()) {
        const min_version = target.os.version_range.semver.min;
        try llvm_triple.writer().print("{d}.{d}.{d}", .{
            min_version.major,
            min_version.minor,
            min_version.patch,
        });
    }
    try llvm_triple.append('-');

    const llvm_abi = switch (target.abi) {
        .none => "unknown",

        .android,
        .code16,
        .coreclr,
        .cygnus,
        .eabi,
        .eabihf,
        .gnu,
        .gnuabi64,
        .gnuabin32,
        .gnueabi,
        .gnueabihf,
        .gnuf32,
        .gnuf64,
        .gnuilp32,
        .gnusf,
        .gnux32,
        .itanium,
        .macabi,
        .msvc,
        .musl,
        .musleabi,
        .musleabihf,
        .muslx32,
        .simulator,
        //
        .amplification,
        .anyhit,
        .callable,
        .closesthit,
        .compute,
        .domain,
        .geometry,
        .hull,
        .intersection,
        .library,
        .mesh,
        .miss,
        .pixel,
        .raygeneration,
        .vertex,
        => |tag| @tagName(tag),
    };
    try llvm_triple.appendSlice(llvm_abi);

    return try llvm_triple.toOwnedSlice();
}

const std = @import("std");
