const std = @import("std");
const builtin = @import("builtin");

pub const zig_version = builtin.zig_version;
pub fn lazy_from_path(path_chars: []const u8, owner: *std.Build) std.Build.LazyPath {
    if (zig_version.major > 0 or zig_version.minor >= 13) {
        return std.Build.LazyPath{ .src_path = .{ .sub_path = path_chars, .owner = owner } };
    } else if (zig_version.minor >= 12) {
        return std.Build.LazyPath{ .path = path_chars };
    } else unreachable;
}

pub fn get_winsdk_path(b: *std.Build, target: std.Build.ResolvedTarget) !?[]const u8 {
    if (target.result.os.tag == .windows) {
        const win_sdk = try std.zig.WindowsSdk.find(b.allocator);
        defer std.zig.WindowsSdk.free(win_sdk, b.allocator);
        if (win_sdk.windows10sdk == null) {
            std.debug.print("Windows 10 SDK could not be found.", .{});
            return null;
        } else {
            const win_sdk_path = try b.allocator.dupe(u8, win_sdk.windows10sdk.?.path);
            return win_sdk_path;
        }
    }
    return null;
}

pub fn get_winrt_path(b: *std.Build, target: std.Build.ResolvedTarget) !?[]const u8 {
    if (target.result.os.tag == .windows) {
        const win_sdk_path = (try get_winsdk_path(b, target)) orelse return null;
        const win_sdk = try std.zig.WindowsSdk.find(b.allocator);
        defer std.zig.WindowsSdk.free(win_sdk, b.allocator);
        if (win_sdk.windows10sdk == null) {
            std.debug.print("Windows 10 SDK could not be found.", .{});
            return null;
        }
        const win_sdk_ver = try b.allocator.dupe(u8, win_sdk.windows10sdk.?.version);
        const winrt_path = try std.fs.path.join(b.allocator, &.{ win_sdk_path, "Include", win_sdk_ver, "winrt" });
        return winrt_path;
    }
    return null;
}

pub fn get_dxil_path(b: *std.Build, target: std.Build.ResolvedTarget) !?[]const u8 {
    var dxil_path: ?[]const u8 = null;
    if (target.result.os.tag == .windows) {
        const win_sdk_path = (try get_winsdk_path(b, target)) orelse return null;
        dxil_path = try std.fs.path.join(b.allocator, &.{ win_sdk_path, "Redist/D3D/x64/dxil.dll" });
    }
    return dxil_path;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_demo = b.option(bool, "build_demo", "Set to true to build a demo executable.") orelse false;
    var sdl_shader = b.option(bool, "sdl_shader", "Set to true to enable building SDL_shadercross as part of the build.") orelse false;
    if (build_demo) {
        sdl_shader = true;
    }

    const spirv_cross_enable_glsl = b.option(bool, "SPIRV_CROSS_ENABLE_GLSL", "Set to true to enable compiling of this spirv feature.") orelse true;
    const spirv_cross_enable_hlsl = b.option(bool, "SPIRV_CROSS_ENABLE_HLSL", "Set to true to enable compiling of this spirv feature.") orelse true;
    const spirv_cross_enable_msl = b.option(bool, "SPIRV_CROSS_ENABLE_MSL", "Set to true to enable compiling of this spirv feature.") orelse true;
    const spirv_cross_enable_cpp = b.option(bool, "SPIRV_CROSS_ENABLE_CPP", "Set to true to enable compiling of this spirv feature.") orelse false;
    const spirv_cross_enable_reflect = b.option(bool, "SPIRV_CROSS_ENABLE_REFLECT", "Set to true to enable compiling of this spirv feature.") orelse true;
    const spirv_cross_enable_c_api = b.option(bool, "SPIRV_CROSS_ENABLE_C_API", "Set to true to enable compiling of this spirv feature.") orelse true;
    const spirv_cross_enable_util = b.option(bool, "SPIRV_CROSS_ENABLE_UTIL", "Set to true to enable compiling of this spirv feature.") orelse true;

    //Set the output directory to use a per-target folder
    const joined_target_str = try std.mem.concat(b.allocator, u8, &.{ @tagName(target.result.cpu.arch), "_", @tagName(target.result.os.tag), "_", @tagName(target.result.abi) });
    b.lib_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str, "lib" });
    b.h_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str, "include" });
    b.exe_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str, "bin" });
    b.dest_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str });

    const sdl = b.dependency("sdl", .{});

    const sdl_lib = b.addStaticLibrary(.{
        .name = "sdl3",
        .optimize = optimize,
        .target = target,
    });

    sdl_lib.linkLibC();
    sdl_lib.addIncludePath(sdl.path("include"));
    sdl_lib.addIncludePath(sdl.path("include/build_config"));
    sdl_lib.addIncludePath(sdl.path("src"));
    const src_root_path = sdl.path("src");
    sdl_lib.addCSourceFiles(.{
        .root = src_root_path,
        .files = &generic_src_files,
    });

    var dxil_path: ?[]const u8 = null;
    if (target.result.os.tag == .windows) {
        sdl_lib.defineCMacro("_WINDOWS", null);
        sdl_lib.defineCMacro("_WIN32", null);

        const win_sdk = try std.zig.WindowsSdk.find(b.allocator);
        defer std.zig.WindowsSdk.free(win_sdk, b.allocator);
        if (win_sdk.windows10sdk == null) {
            std.debug.print("Windows 10 SDK could not be found.", .{});
            return;
        } else {
            const win_sdk_path = win_sdk.windows10sdk.?.path;
            const win_sdk_ver = win_sdk.windows10sdk.?.version;
            const winrt_path = try std.fs.path.join(b.allocator, &.{ win_sdk_path, "Include", win_sdk_ver, "winrt" });
            defer b.allocator.free(winrt_path);
            sdl_lib.addSystemIncludePath(lazy_from_path(winrt_path, b));

            dxil_path = try std.fs.path.join(b.allocator, &.{ win_sdk_path, "Redist/D3D/x64/dxil.dll" });
        }
    }

    if (target.result.abi.isGnu()) {
        sdl_lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", null);
    }

    switch (target.result.os.tag) {
        .windows => {
            sdl_lib.addCSourceFiles(.{
                .root = src_root_path,
                .files = &windows_src_files,
            });
            sdl_lib.linkSystemLibrary("setupapi");
            sdl_lib.linkSystemLibrary("winmm");
            sdl_lib.linkSystemLibrary("gdi32");
            sdl_lib.linkSystemLibrary("imm32");
            sdl_lib.linkSystemLibrary("version");
            sdl_lib.linkSystemLibrary("oleaut32");
            sdl_lib.linkSystemLibrary("ole32");
        },
        else => {
            const config_header = b.addConfigHeader(.{
                .style = .{ .cmake = sdl.path("include/build_config/SDL_config.h.cmake") },
                .include_path = "sdl3/SDL_config.h",
            }, .{});
            sdl_lib.addConfigHeader(config_header);
            sdl_lib.installConfigHeader(config_header);
        },
    }

    //Reference this lib through the depenendency in your own build.zig, and link against it.
    b.installArtifact(sdl_lib);

    //Add the licenses to the lib directory
    sdl_lib.installHeader(sdl.path("LICENSE.txt"), "../lib/SDL_LICENSE.txt");
    sdl_lib.installHeader(sdl.path("CREDITS.md"), "../lib/SDL_CREDITS.md");
    sdl_lib.installHeader(sdl.path("src/video/yuv2rgb/LICENSE"), "../lib/yuv2rgb_LICENSE");
    sdl_lib.installHeader(sdl.path("src/hidapi/LICENSE-bsd.txt"), "../lib/hidapi_LICENSE.txt");

    const translate_sdl_header = b.addTranslateC(.{
        .root_source_file = lazy_from_path("translate_include.h", b),
        .target = target,
        .optimize = optimize,
    });
    translate_sdl_header.addIncludeDir(sdl.path("include").getPath(b));
    if (target.result.os.tag == .windows) {
        translate_sdl_header.defineCMacroRaw("_WINDOWS=");
        translate_sdl_header.defineCMacroRaw("_WIN32=");
    }
    if (target.result.abi.isGnu()) {
        translate_sdl_header.defineCMacroRaw("SDL_USE_BUILTIN_OPENGL_DEFINITIONS=");
    }

    const installed_sdl_zig = try std.fs.path.join(b.allocator, &.{ joined_target_str, "sdl.zig" });
    const installFile = b.addInstallFile(translate_sdl_header.getOutput(), installed_sdl_zig);
    installFile.step.dependOn(&translate_sdl_header.step);
    b.getInstallStep().dependOn(&installFile.step);

    //Reference this module through the depenendency in your own build.zig, and import it.
    const sdl_module = b.addModule("sdl", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = translate_sdl_header.getOutput(),
    });

    if (sdl_shader) {
        const sdl_shadercross_lib = b.addStaticLibrary(.{
            .name = "sdl3_gpu_shadercross",
            .optimize = optimize,
            .target = target,
        });

        const sdl_shadercross = b.dependency("sdl_shadercross", .{});
        const spirv_cross = b.dependency("spirv_cross", .{});

        sdl_shadercross_lib.addCSourceFiles(.{
            .root = spirv_cross.path(""),
            .files = &spirv_cross_core_src,
        });

        if (spirv_cross_enable_glsl) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_glsl_src,
            });
        }

        if (spirv_cross_enable_hlsl) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_hlsl_src,
            });
        }

        if (spirv_cross_enable_msl) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_msl_src,
            });
        }

        if (spirv_cross_enable_cpp) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_cpp_src,
            });
        }

        if (spirv_cross_enable_reflect) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_reflect_src,
            });
        }

        if (spirv_cross_enable_c_api) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_c_src,
            });
        }

        if (spirv_cross_enable_util) {
            sdl_shadercross_lib.addCSourceFiles(.{
                .root = spirv_cross.path(""),
                .files = &spirv_cross_util_src,
            });
        }

        sdl_shadercross_lib.defineCMacro("SPIRV_CROSS_VERSION", "0.64.0");
        sdl_shadercross_lib.defineCMacro("SDL_GPU_SHADERCROSS_SPIRVCROSS", "1");
        if (target.result.os.tag == .windows) {
            sdl_shadercross_lib.defineCMacro("_WINDOWS", null);
            sdl_shadercross_lib.defineCMacro("_WIN32", null);
        }
        if (target.result.abi.isGnu()) {
            sdl_shadercross_lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", null);
        }

        sdl_shadercross_lib.addCSourceFiles(.{
            .root = sdl_shadercross.path("src"),
            .files = &.{
                "SDL_gpu_shadercross.c",
            },
        });
        sdl_shadercross_lib.addIncludePath(sdl_shadercross.path("include"));
        sdl_shadercross_lib.addIncludePath(spirv_cross.path(""));
        sdl_shadercross_lib.addIncludePath(sdl.path("include"));
        sdl_shadercross_lib.linkLibrary(sdl_lib);
        sdl_shadercross_lib.installHeader(sdl_shadercross.path("include/SDL3_gpu_shadercross/SDL_gpu_shadercross.h"), "SDL_gpu_shadercross.h");

        //Licenses
        sdl_shadercross_lib.installHeader(sdl_shadercross.path("LICENSE.txt"), "../lib/sdl3_gpu_shadercross_LICENSE.txt");
        sdl_shadercross_lib.installHeader(spirv_cross.path("LICENSE"), "../lib/spirv_cross_LICENSE");

        b.installArtifact(sdl_shadercross_lib);

        translate_sdl_header.defineCMacroRaw("ZIG_SDL_SHADERCROSS=");
        translate_sdl_header.defineCMacroRaw("SDL_GPU_SHADERCROSS_SPIRVCROSS=1");
        translate_sdl_header.addIncludeDir(sdl_shadercross.path("include").getPath(b));

        if (build_demo) {
            const demo_exe = b.addExecutable(.{ .name = "demo", .target = target, .optimize = optimize, .root_source_file = b.path("example/demo.zig") });
            demo_exe.root_module.addImport("sdl", sdl_module);
            demo_exe.linkLibrary(sdl_lib);
            demo_exe.linkLibrary(sdl_shadercross_lib);
            if (target.result.os.tag == .windows) {
                const installDxil = b.addInstallBinFile(.{ .cwd_relative = dxil_path.? }, "dxil.dll");
                demo_exe.step.dependOn(&installDxil.step);
            }

            b.installDirectory(.{
                .source_dir = lazy_from_path("example/content", b),
                .install_dir = .bin,
                .install_subdir = "content",
            });

            switch (target.result.os.tag) {
                .windows => {
                    demo_exe.linkSystemLibrary("setupapi");
                    demo_exe.linkSystemLibrary("winmm");
                    demo_exe.linkSystemLibrary("gdi32");
                    demo_exe.linkSystemLibrary("imm32");
                    demo_exe.linkSystemLibrary("version");
                    demo_exe.linkSystemLibrary("oleaut32");
                    demo_exe.linkSystemLibrary("ole32");
                    demo_exe.linkSystemLibrary("User32");
                    demo_exe.linkSystemLibrary("Advapi32");
                    demo_exe.linkSystemLibrary("Shell32");
                },
                else => {
                    //TODO
                },
            }

            b.installArtifact(demo_exe);
        }
    }
}

const generic_src_files = [_][]const u8{
    "SDL.c",
    "SDL_assert.c",
    "SDL_error.c",
    "SDL_guid.c",
    "SDL_hashtable.c",
    "SDL_hints.c",
    "SDL_list.c",
    "SDL_log.c",
    "SDL_properties.c",
    "SDL_utils.c",
    "atomic/SDL_atomic.c",
    "atomic/SDL_spinlock.c",
    "audio/SDL_audio.c",
    "audio/SDL_audiocvt.c",
    "audio/SDL_audiodev.c",
    "audio/SDL_audioqueue.c",
    "audio/SDL_audioresample.c",
    "audio/SDL_audiotypecvt.c",
    "audio/SDL_mixer.c",
    "audio/SDL_wave.c",

    "audio/disk/SDL_diskaudio.c",
    "audio/dummy/SDL_dummyaudio.c",
    "camera/SDL_camera.c",
    "camera/dummy/SDL_camera_dummy.c",
    "camera/mediafoundation/SDL_camera_mediafoundation.c",
    "core/SDL_core_unsupported.c",

    "cpuinfo/SDL_cpuinfo.c",
    "dialog/SDL_dialog_utils.c",
    "dynapi/SDL_dynapi.c",
    "events/SDL_categories.c",
    "events/SDL_clipboardevents.c",
    "events/SDL_displayevents.c",
    "events/SDL_dropevents.c",
    "events/SDL_events.c",
    "events/SDL_keyboard.c",
    "events/SDL_keymap.c",
    "events/SDL_mouse.c",
    "events/SDL_pen.c",
    "events/SDL_quit.c",
    "events/SDL_touch.c",
    "events/SDL_windowevents.c",
    "file/SDL_iostream.c",
    "filesystem/SDL_filesystem.c",
    "gpu/SDL_gpu.c",
    "haptic/SDL_haptic.c",
    "haptic/dummy/SDL_syshaptic.c",
    "hidapi/SDL_hidapi.c",
    "joystick/SDL_gamepad.c",
    "joystick/SDL_joystick.c",
    "joystick/SDL_steam_virtual_gamepad.c",
    "joystick/controller_type.c",
    "joystick/dummy/SDL_sysjoystick.c",
    "joystick/gdk/SDL_gameinputjoystick.c",
    "joystick/hidapi/SDL_hidapi_combined.c",
    "joystick/hidapi/SDL_hidapi_gamecube.c",
    "joystick/hidapi/SDL_hidapi_luna.c",
    "joystick/hidapi/SDL_hidapi_ps3.c",
    "joystick/hidapi/SDL_hidapi_ps4.c",
    "joystick/hidapi/SDL_hidapi_ps5.c",
    "joystick/hidapi/SDL_hidapi_rumble.c",
    "joystick/hidapi/SDL_hidapi_shield.c",
    "joystick/hidapi/SDL_hidapi_stadia.c",
    "joystick/hidapi/SDL_hidapi_steam.c",
    "joystick/hidapi/SDL_hidapi_steam_hori.c",
    "joystick/hidapi/SDL_hidapi_steamdeck.c",
    "joystick/hidapi/SDL_hidapi_switch.c",
    "joystick/hidapi/SDL_hidapi_wii.c",
    "joystick/hidapi/SDL_hidapi_xbox360.c",
    "joystick/hidapi/SDL_hidapi_xbox360w.c",
    "joystick/hidapi/SDL_hidapi_xboxone.c",
    "joystick/hidapi/SDL_hidapijoystick.c",
    "joystick/virtual/SDL_virtualjoystick.c",
    "libm/e_atan2.c",
    "libm/e_exp.c",
    "libm/e_fmod.c",
    "libm/e_log.c",
    "libm/e_log10.c",
    "libm/e_pow.c",
    "libm/e_rem_pio2.c",
    "libm/e_sqrt.c",
    "libm/k_cos.c",
    "libm/k_rem_pio2.c",
    "libm/k_sin.c",
    "libm/k_tan.c",
    "libm/s_atan.c",
    "libm/s_copysign.c",
    "libm/s_cos.c",
    "libm/s_fabs.c",
    "libm/s_floor.c",
    "libm/s_isinf.c",
    "libm/s_isinff.c",
    "libm/s_isnan.c",
    "libm/s_isnanf.c",
    "libm/s_modf.c",
    "libm/s_scalbn.c",
    "libm/s_sin.c",
    "libm/s_tan.c",
    "locale/SDL_locale.c",
    "main/SDL_main_callbacks.c",
    "main/SDL_runapp.c",
    "main/generic/SDL_sysmain_callbacks.c",
    "misc/SDL_url.c",
    "power/SDL_power.c",
    "process/SDL_process.c",
    "render/SDL_d3dmath.c",
    "render/SDL_render.c",
    "render/SDL_render_unsupported.c",
    "render/SDL_yuv_sw.c",
    "render/gpu/SDL_pipeline_gpu.c",
    "render/gpu/SDL_render_gpu.c",
    "render/gpu/SDL_shaders_gpu.c",
    "render/opengl/SDL_render_gl.c",
    "render/opengl/SDL_shaders_gl.c",
    "render/opengles2/SDL_render_gles2.c",
    "render/opengles2/SDL_shaders_gles2.c",
    "render/software/SDL_blendfillrect.c",
    "render/software/SDL_blendline.c",
    "render/software/SDL_blendpoint.c",
    "render/software/SDL_drawline.c",
    "render/software/SDL_drawpoint.c",
    "render/software/SDL_render_sw.c",
    "render/software/SDL_rotate.c",
    "render/software/SDL_triangle.c",
    "render/vulkan/SDL_render_vulkan.c",
    "render/vulkan/SDL_shaders_vulkan.c",
    "sensor/SDL_sensor.c",
    "sensor/dummy/SDL_dummysensor.c",
    "stdlib/SDL_crc16.c",
    "stdlib/SDL_crc32.c",
    "stdlib/SDL_getenv.c",
    "stdlib/SDL_iconv.c",
    "stdlib/SDL_malloc.c",
    "stdlib/SDL_memcpy.c",
    "stdlib/SDL_memmove.c",
    "stdlib/SDL_memset.c",
    "stdlib/SDL_mslibc.c",
    "stdlib/SDL_murmur3.c",
    "stdlib/SDL_qsort.c",
    "stdlib/SDL_random.c",
    "stdlib/SDL_stdlib.c",
    "stdlib/SDL_string.c",
    "stdlib/SDL_strtokr.c",
    "storage/SDL_storage.c",
    "storage/generic/SDL_genericstorage.c",
    "storage/steam/SDL_steamstorage.c",
    "thread/SDL_thread.c",
    "thread/generic/SDL_syscond.c",
    "thread/generic/SDL_sysrwlock.c",
    "time/SDL_time.c",
    "timer/SDL_timer.c",
    "video/SDL_RLEaccel.c",
    "video/SDL_blit.c",
    "video/SDL_blit_0.c",
    "video/SDL_blit_1.c",
    "video/SDL_blit_A.c",
    "video/SDL_blit_N.c",
    "video/SDL_blit_auto.c",
    "video/SDL_blit_copy.c",
    "video/SDL_blit_slow.c",
    "video/SDL_bmp.c",
    "video/SDL_clipboard.c",
    "video/SDL_egl.c",
    "video/SDL_fillrect.c",
    "video/SDL_pixels.c",
    "video/SDL_rect.c",
    "video/SDL_stretch.c",
    "video/SDL_surface.c",
    "video/SDL_video.c",
    "video/SDL_video_unsupported.c",
    "video/SDL_vulkan_utils.c",
    "video/SDL_yuv.c",
    "video/dummy/SDL_nullevents.c",
    "video/dummy/SDL_nullframebuffer.c",
    "video/dummy/SDL_nullvideo.c",
    "video/offscreen/SDL_offscreenevents.c",
    "video/offscreen/SDL_offscreenframebuffer.c",
    "video/offscreen/SDL_offscreenopengles.c",
    "video/offscreen/SDL_offscreenvideo.c",
    "video/offscreen/SDL_offscreenvulkan.c",
    "video/offscreen/SDL_offscreenwindow.c",
    "video/yuv2rgb/yuv_rgb_lsx.c",
    "video/yuv2rgb/yuv_rgb_sse.c",
    "video/yuv2rgb/yuv_rgb_std.c",
};

const windows_src_files = [_][]const u8{
    "audio/directsound/SDL_directsound.c",
    "audio/wasapi/SDL_wasapi.c",
    "audio/wasapi/SDL_wasapi_win32.c",
    "core/windows/SDL_hid.c",
    "core/windows/SDL_immdevice.c",
    "core/windows/SDL_windows.c",
    "core/windows/SDL_xinput.c",
    "filesystem/windows/SDL_sysfilesystem.c",
    "filesystem/windows/SDL_sysfsops.c",
    "gpu/d3d11/SDL_gpu_d3d11.c",
    "gpu/d3d12/SDL_gpu_d3d12.c",
    "gpu/vulkan/SDL_gpu_vulkan.c",
    "dialog/windows/SDL_windowsdialog.c",
    "haptic/windows/SDL_dinputhaptic.c",
    "haptic/windows/SDL_windowshaptic.c",
    "joystick/windows/SDL_dinputjoystick.c",
    "joystick/windows/SDL_rawinputjoystick.c",
    "joystick/windows/SDL_windows_gaming_input.c",
    "joystick/windows/SDL_windowsjoystick.c",
    "joystick/windows/SDL_xinputjoystick.c",
    "loadso/windows/SDL_sysloadso.c",
    "locale/windows/SDL_syslocale.c",
    "main/windows/SDL_sysmain_runapp.c",
    "misc/windows/SDL_sysurl.c",
    "power/windows/SDL_syspower.c",
    "process/windows/SDL_windowsprocess.c",
    "render/direct3d/SDL_render_d3d.c",
    "render/direct3d/SDL_shaders_d3d.c",
    "render/direct3d11/SDL_render_d3d11.c",
    "render/direct3d11/SDL_shaders_d3d11.c",
    "render/direct3d12/SDL_render_d3d12.c",
    "render/direct3d12/SDL_shaders_d3d12.c",
    "sensor/windows/SDL_windowssensor.c",
    "thread/windows/SDL_syscond_cv.c",
    "thread/windows/SDL_sysmutex.c",
    "thread/windows/SDL_sysrwlock_srw.c",
    "thread/windows/SDL_syssem.c",
    "thread/windows/SDL_systhread.c",
    "thread/windows/SDL_systls.c",
    "time/windows/SDL_systime.c",
    "timer/windows/SDL_systimer.c",
    "video/windows/SDL_windowsclipboard.c",
    "video/windows/SDL_windowsevents.c",
    "video/windows/SDL_windowsframebuffer.c",
    "video/windows/SDL_windowsgameinput.c",
    "video/windows/SDL_windowskeyboard.c",
    "video/windows/SDL_windowsmessagebox.c",
    "video/windows/SDL_windowsmodes.c",
    "video/windows/SDL_windowsmouse.c",
    "video/windows/SDL_windowsopengl.c",
    "video/windows/SDL_windowsopengles.c",
    "video/windows/SDL_windowsrawinput.c",
    "video/windows/SDL_windowsshape.c",
    "video/windows/SDL_windowsvideo.c",
    "video/windows/SDL_windowsvulkan.c",
    "video/windows/SDL_windowswindow.c",
};

const spirv_cross_core_src = [_][]const u8{
    "spirv_cross.cpp",
    "spirv_parser.cpp",
    "spirv_cross_parsed_ir.cpp",
    "spirv_cfg.cpp",
};

const spirv_cross_c_src = [_][]const u8{
    "spirv_cross_c.cpp",
};

const spirv_cross_glsl_src = [_][]const u8{
    "spirv_glsl.cpp",
};

const spirv_cross_hlsl_src = [_][]const u8{
    "spirv_hlsl.cpp",
};

const spirv_cross_msl_src = [_][]const u8{
    "spirv_msl.cpp",
};

const spirv_cross_cpp_src = [_][]const u8{
    "spirv_cpp.cpp",
};

const spirv_cross_reflect_src = [_][]const u8{
    "spirv_reflect.cpp",
};

const spirv_cross_util_src = [_][]const u8{
    "spirv_cross_util.cpp",
};
