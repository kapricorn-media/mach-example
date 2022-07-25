const std = @import("std");
const builtin = @import("builtin");

pub const gpu = @import("deps/mach/gpu/build.zig");
const gpu_dawn = @import("deps/mach/gpu-dawn/build.zig");
pub const glfw = @import("deps/mach/glfw/build.zig");
pub const ecs = @import("deps/mach/ecs/build.zig");
const freetype = @import("deps/mach/freetype/build.zig");
const sysaudio = @import("deps/mach/sysaudio/build.zig");
const sysjs = @import("deps/mach/sysjs/build.zig");

pub const pkg = std.build.Pkg{
    .name = "mach",
    .source = .{ .path = "deps/mach/src/main.zig" },
    .dependencies = &.{ gpu.pkg, ecs.pkg },
};

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

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

    const gpu_dawn_options = gpu_dawn.Options{
        .from_source = b.option(bool, "dawn-from-source", "Build Dawn from source") orelse false,
    };
    const options = Options{ .gpu_dawn_options = gpu_dawn_options };

    const app = App.init(
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
    // inline for (example.packages) |p| {
    //     if (std.mem.eql(u8, p.name, freetype.pkg.name))
    //         freetype.link(app.b, app.step, .{});

    //     if (std.mem.eql(u8, p.name, sysaudio.pkg.name))
    //         sysaudio.link(app.b, app.step, .{});
    // }

    app.link(options);
    app.install();

    // const example_compile_step = b.step("example-" ++ example.name, "Compile '" ++ example.name ++ "' example");
    // example_compile_step.dependOn(&app.getInstallStep().?.step);

    // const example_run_cmd = app.run();
    // example_run_cmd.step.dependOn(&app.getInstallStep().?.step);
    // const example_run_step = b.step("run-example-" ++ example.name, "Run '" ++ example.name ++ "' example");
    // example_run_step.dependOn(&example_run_cmd.step);

    // if (target.toTarget().cpu.arch != .wasm32) {
    //     const shaderexp_app = App.init(
    //         b,
    //         .{
    //             .name = "shaderexp",
    //             .src = "shaderexp/main.zig",
    //             .target = target,
    //         },
    //     );
    //     shaderexp_app.setBuildMode(mode);
    //     shaderexp_app.link(options);
    //     shaderexp_app.install();

    //     const shaderexp_compile_step = b.step("shaderexp", "Compile shaderexp");
    //     shaderexp_compile_step.dependOn(&shaderexp_app.getInstallStep().?.step);

    //     const shaderexp_run_cmd = shaderexp_app.run();
    //     shaderexp_run_cmd.step.dependOn(&shaderexp_app.getInstallStep().?.step);
    //     const shaderexp_run_step = b.step("run-shaderexp", "Run shaderexp");
    //     shaderexp_run_step.dependOn(&shaderexp_run_cmd.step);
    // }

    // const compile_all = b.step("compile-all", "Compile all examples and applications");
    // compile_all.dependOn(b.getInstallStep());

    // // compiles the `libmach` shared library
    // const lib = b.addSharedLibrary("mach", "src/platform/libmach.zig", .unversioned);
    // lib.setTarget(target);
    // lib.setBuildMode(mode);
    // lib.main_pkg_path = "src/";
    // const app_pkg = std.build.Pkg{
    //     .name = "app",
    //     .source = .{ .path = "src/platform/libmach.zig" },
    // };
    // lib.addPackage(app_pkg);
    // lib.addPackage(gpu.pkg);
    // lib.addPackage(glfw.pkg);
    // const gpu_options = gpu.Options{
    //     .glfw_options = @bitCast(@import("gpu/libs/mach-glfw/build.zig").Options, options.glfw_options),
    //     .gpu_dawn_options = @bitCast(@import("gpu/libs/mach-gpu-dawn/build.zig").Options, options.gpu_dawn_options),
    // };
    // glfw.link(b, lib, options.glfw_options);
    // gpu.link(b, lib, gpu_options);
    // lib.setOutputDir("./libmach/build");
    // lib.install();
}

pub const Options = struct {
    glfw_options: glfw.Options = .{},
    gpu_dawn_options: gpu_dawn.Options = .{},
};

// const Packages = struct {
//     // Declared here because submodule may not be cloned at the time build.zig runs.
//     const zmath = std.build.Pkg{
//         .name = "zmath",
//         .source = .{ .path = "examples/libs/zmath/src/zmath.zig" },
//     };
//     const zigimg = std.build.Pkg{
//         .name = "zigimg",
//         .source = .{ .path = "examples/libs/zigimg/zigimg.zig" },
//     };
// };

const web_install_dir = std.build.InstallDir{ .custom = "www" };

pub const App = struct {
    b: *std.build.Builder,
    name: []const u8,
    step: *std.build.LibExeObjStep,
    platform: Platform,
    res_dirs: ?[]const []const u8,

    pub const Platform = enum {
        native,
        web,

        pub fn fromTarget(target: std.Target) Platform {
            if (target.cpu.arch == .wasm32) return .web;
            return .native;
        }
    };

    pub fn init(b: *std.build.Builder, options: struct {
        name: []const u8,
        src: []const u8,
        target: std.zig.CrossTarget,
        deps: ?[]const std.build.Pkg = null,
        res_dirs: ?[]const []const u8 = null,
    }) App {
        const target = (std.zig.system.NativeTargetInfo.detect(b.allocator, options.target) catch unreachable).target;
        const platform = Platform.fromTarget(target);

        var deps = std.ArrayList(std.build.Pkg).init(b.allocator);
        deps.append(pkg) catch unreachable;
        deps.append(gpu.pkg) catch unreachable;
        switch (platform) {
            .native => deps.append(glfw.pkg) catch unreachable,
            .web => deps.append(sysjs.pkg) catch unreachable,
        }
        if (options.deps) |app_deps| deps.appendSlice(app_deps) catch unreachable;

        const app_pkg = std.build.Pkg{
            .name = "app",
            .source = .{ .path = options.src },
            .dependencies = deps.toOwnedSlice(),
        };

        const step = blk: {
            if (platform == .web) {
                const lib = b.addSharedLibrary(options.name, "deps/mach/src/platform/wasm.zig", .unversioned);
                lib.addPackage(gpu.pkg);
                lib.addPackage(sysjs.pkg);

                break :blk lib;
            } else {
                const exe = b.addExecutable(options.name, "deps/mach/src/platform/native.zig");
                exe.addPackage(gpu.pkg);
                exe.addPackage(glfw.pkg);

                break :blk exe;
            }
        };

        step.main_pkg_path = "deps/mach/src";
        step.addPackage(app_pkg);
        step.setTarget(options.target);

        return .{
            .b = b,
            .step = step,
            .name = options.name,
            .platform = platform,
            .res_dirs = options.res_dirs,
        };
    }

    pub fn install(app: *const App) void {
        app.step.install();

        // Install additional files (src/mach.js and template.html)
        // in case of wasm
        if (app.platform == .web) {
            // Set install directory to '{prefix}/www'
            app.getInstallStep().?.dest_dir = web_install_dir;

            inline for (.{ "/src/platform/mach.js", "/sysjs/src/mach-sysjs.js" }) |js| {
                const install_js = app.b.addInstallFileWithDir(
                    .{ .path = thisDir() ++ js },
                    web_install_dir,
                    std.fs.path.basename(js),
                );
                app.getInstallStep().?.step.dependOn(&install_js.step);
            }

            const html_generator = app.b.addExecutable("html-generator", thisDir() ++ "/tools/html-generator.zig");
            html_generator.main_pkg_path = thisDir();
            const run_html_generator = html_generator.run();
            run_html_generator.addArgs(&.{ std.mem.concat(
                app.b.allocator,
                u8,
                &.{ app.name, ".html" },
            ) catch unreachable, app.name });

            run_html_generator.cwd = app.b.getInstallPath(web_install_dir, "");
            app.getInstallStep().?.step.dependOn(&run_html_generator.step);
        }

        // Install resources
        if (app.res_dirs) |res_dirs| {
            for (res_dirs) |res| {
                const install_res = app.b.addInstallDirectory(.{
                    .source_dir = res,
                    .install_dir = app.getInstallStep().?.dest_dir,
                    .install_subdir = std.fs.path.basename(res),
                    .exclude_extensions = &.{},
                });
                app.getInstallStep().?.step.dependOn(&install_res.step);
            }
        }
    }

    pub fn link(app: *const App, options: Options) void {
        const gpu_options = gpu.Options{
            .glfw_options = @bitCast(@import("deps/mach/gpu/libs/mach-glfw/build.zig").Options, options.glfw_options),
            .gpu_dawn_options = @bitCast(@import("deps/mach/gpu/libs/mach-gpu-dawn/build.zig").Options, options.gpu_dawn_options),
        };

        if (app.platform != .web) {
            glfw.link(app.b, app.step, options.glfw_options);
            gpu.link(app.b, app.step, gpu_options);
        }
    }

    pub fn setBuildMode(app: *const App, mode: std.builtin.Mode) void {
        app.step.setBuildMode(mode);
    }

    pub fn getInstallStep(app: *const App) ?*std.build.InstallArtifactStep {
        return app.step.install_step;
    }

    // pub fn run(app: *const App) *std.build.RunStep {
    //     if (app.platform == .web) {
    //         ensureDependencySubmodule(app.b.allocator, "tools/libs/apple_pie") catch unreachable;

    //         const http_server = app.b.addExecutable("http-server", thisDir() ++ "/tools/http-server.zig");
    //         http_server.addPackage(.{
    //             .name = "apple_pie",
    //             .source = .{ .path = "tools/libs/apple_pie/src/apple_pie.zig" },
    //         });

    //         // NOTE: The launch actually takes place in reverse order. The browser is launched first
    //         // and then the http-server.
    //         // This is because running the server would block the process (a limitation of current
    //         // RunStep). So we assume that (xdg-)open is a launcher and not a blocking process.

    //         const address = std.process.getEnvVarOwned(app.b.allocator, "MACH_ADDRESS") catch "127.0.0.1";
    //         const port = std.process.getEnvVarOwned(app.b.allocator, "MACH_PORT") catch "8000";

    //         const launch = app.b.addSystemCommand(&.{
    //             switch (builtin.os.tag) {
    //                 .macos, .windows => "open",
    //                 else => "xdg-open", // Assume linux-like
    //             },
    //             app.b.fmt("http://{s}:{s}/{s}.html", .{ address, port, app.name }),
    //         });
    //         launch.step.dependOn(&app.getInstallStep().?.step);

    //         const serve = http_server.run();
    //         serve.addArgs(&.{ app.name, address, port });
    //         serve.step.dependOn(&launch.step);
    //         serve.cwd = app.b.getInstallPath(web_install_dir, "");

    //         return serve;
    //     } else {
    //         return app.step.run();
    //     }
    // }
};
