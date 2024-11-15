const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Run unit tests");
    b.default_step = test_step;

    const module1 = b.createModule(.{
        .root_source_file = b.path("module1/main.zig"),
    });
    const module2 = b.createModule(.{
        .root_source_file = b.path("module2/main.zig"),
        .imports = &.{.{
            .name = "module1",
            .module = module1,
        }},
    });

    const t = b.addTest2(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
            .imports = &.{.{
                .name = "module2",
                .module = module2,
            }},
        }),
        .test_runner = b.path("test_runner/main.zig"),
    });

    test_step.dependOn(&b.addRunArtifact(t).step);
}
