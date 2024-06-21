const std = @import("std");

// These comments are only explanatory, you can safely remove them.

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. By default it creates 3 options,
    // "target", "cpu" and "dynamic-linker", which user can pass to `zig build`:
    // -Dtarget=x86_64-linux-gnu -Dcpu=x86_64_v2
    // If option is omitted, it defaults to "native".
    //
    // This function accepts a struct, `std.Build.StandardTargetOptionsArgs`,
    // which is created here by using `.{}` syntax. If you want different
    // default target or add a list of allowed targets, you need to
    // set fields when creating a struct, like this:
    //
    // const target = b.standardTargetOptions(.{
    //     .default_target = [...],
    //     .whitelist = [...],
    // });
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // optimize mode for building. By default it creates 1 option,
    // "optimize", which user can pass to `zig build`:
    // -Doptimize=ReleaseSafe
    // If omitted, it defaults to "Debug".
    //
    // This function accepts a different struct,
    // `std.Build.StandardOptimizeOptionOptions`. You can set
    // preferred optimize mode here, which will completely change
    // behaviour:
    // * "optimize" option will be replaced with "release" option,
    //   that accepts only a boolean, and which user can pass like this:
    // -Drelease=true
    // * Both users of `zig build` and projects that depend on this
    // project using package manager will be restricted to only 2
    // optimize mode, Debug and the one that you chose. This means
    // that, for example, if you chose ReleaseSmall, some project
    // which imports module from this project will not be able to
    // make it compile with ReleaseSafe like the rest of his code
    // or modules.
    const optimize = b.standardOptimizeOption(.{});

    // [WIP] This is how you pass options to dependency:
    // const some_dep = b.dependency("dep", .{
    //     .target = target,
    //     // If author did not restrict optimize modes:
    //     .optimize = optimize,
    //     // If author did restrict optimize modes:
    //     .release = true, // or false, you choose
    // });

    // By default bla-bla-bla, you can bla-bla-bla
    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");

    //
    {
        const main_mod = b.addExecutable(.{
            // In this case the main source file is merely a path, however, in more
            // complicated build scripts, this could be a generated file.
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        const main_exe = b.addExecutable2(.{
            .name = "$",
            .root_module = main_mod,
        });

        // This declares intent for the executable to be installed into the
        // standard location when the user invokes the "install" step (the default
        // step when running `zig build`).
        b.installArtifact(main_exe);

        // This *creates* a Run step in the build graph, to be executed when another
        // step is evaluated that depends on it. The next line below will establish
        // such a dependency.
        const run_cmd = b.addRunArtifact(main_exe);

        // By making the run step depend on the install step, it will be run from the
        // installation directory rather than directly from within the cache directory.
        // This is not necessary, however, if the application depends on other installed
        // files, this ensures they will be present and in the expected location.
        run_cmd.step.dependOn(b.getInstallStep());

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build run -- arg1 arg2 etc`
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        // This creates a build step. It will be visible in the `zig build --help` menu,
        // and can be selected like this: `zig build run`
        // This will evaluate the `run` step rather than the default, which is "install".
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        // Creates a step for unit testing. This only builds the test executable
        // but does not run it.
        const main_unit_tests = b.addTest2(.{
            .root_module = main_mod,
        });

        const run_exe_unit_tests = b.addRunArtifact(main_unit_tests);

        test_step.dependOn(&run_exe_unit_tests.step);
    }

    // Same, but for static library. Comments are omitted
    // because everything is mostly same.
    {
        const export_mod = b.createModule(.{
            .root_source_file = b.path("src/export.zig"),
            .target = target,
            .optimize = optimize,
        });

        const export_lib = b.addLibrary(.{
            .name = "$",
            .root_module = export_mod,
            .linkage = .static,
        });

        b.installArtifact(export_lib);

        const export_unit_tests = b.addTest2(.{
            .root_module = export_mod,
        });

        const run_lib_unit_tests = b.addRunArtifact(export_unit_tests);

        test_step.dependOn(&run_lib_unit_tests.step);
    }
}
