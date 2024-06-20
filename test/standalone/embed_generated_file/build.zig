const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
    });

    const bootloader = b.addExecutable2(.{
        .name = "bootloader",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bootloader.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        }),
    });

    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = .Debug,
    });
    main_mod.addAnonymousImport("bootloader.elf", .{
        .root_source_file = bootloader.getEmittedBin(),
    });

    const exe = b.addTest2(.{
        .root_module = main_mod,
    });

    // TODO: actually check the output
    _ = exe.getEmittedBin();

    test_step.dependOn(&exe.step);
}
