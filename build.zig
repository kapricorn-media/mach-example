const std = @import("std");
const builtin = @import("builtin");

const mach_build = @import("deps/mach/build.zig");

const Packages = struct {
    const zmath = std.build.Pkg{
        .name = "zmath",
        .source = .{ .path = "deps/zmath/src/zmath.zig" },
    };
    const zigimg = std.build.Pkg{
        .name = "zigimg",
        .source = .{ .path = "deps/zigimg/zigimg.zig" },
    };
};

pub fn build(b: *std.build.Builder) void
{
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});
    const options = mach_build.Options{
        .gpu_dawn_options = .{
            .from_source = b.option(bool, "dawn-from-source", "Build Dawn from source") orelse false,
        },
    };

    const app = mach_build.App.init(
        b,
        .{
            .name = "example",
            .src = "src/main.zig",
            .target = target,
            .deps = &[_]std.build.Pkg{ Packages.zmath, Packages.zigimg },
            .res_dirs = &[_][]const u8 {"data/"},
        }
    );
    app.setBuildMode(mode);
    app.link(options);
    app.install();

    const runTests = b.step("test", "Run tests");
    const testSrcs = [_][]const u8 {
        // TODO
    };
    for (testSrcs) |src| {
        const tests = b.addTest(src);
        tests.setBuildMode(mode);
        tests.setTarget(target);
        runTests.dependOn(&tests.step);
    }
}
