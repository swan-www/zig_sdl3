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

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    if (target.result.os.tag == .windows) {
        sdl_lib.defineCMacro("_WINDOWS", null);
        sdl_lib.defineCMacro("_WIN32", null);

        const win_sdk = try std.zig.WindowsSdk.find(b.allocator);
        defer std.zig.WindowsSdk.free(win_sdk, b.allocator);
        if (win_sdk.windows10sdk == null) {
            try sdl_lib.step.addError("Windows 10 SDK could not be found.", .{});
        } else {
            const win_sdk_path = win_sdk.windows10sdk.?.path;
            const win_sdk_ver = win_sdk.windows10sdk.?.version;
            const winrt_path = try std.fs.path.join(b.allocator, &.{ win_sdk_path, "Include", win_sdk_ver, "winrt" });
            defer b.allocator.free(winrt_path);
            sdl_lib.addSystemIncludePath(lazy_from_path(winrt_path, b));
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

    const translate_sdl_header = b.addTranslateC(.{
        .root_source_file = sdl.path("include/SDL3/SDL.h"),
        .target = target,
        .optimize = optimize,
    });
    const include_str = sdl.path("include").getPath(b);
    translate_sdl_header.addIncludeDir(include_str);
    if (target.result.os.tag == .windows) {
        translate_sdl_header.defineCMacroRaw("_WINDOWS=");
        translate_sdl_header.defineCMacroRaw("_WIN32=");
    }
    if (target.result.abi.isGnu()) {
        translate_sdl_header.defineCMacroRaw("SDL_USE_BUILTIN_OPENGL_DEFINITIONS=");
    }

    const installFile = b.addInstallFile(translate_sdl_header.getOutput(), "sdl.zig");
    installFile.step.dependOn(&translate_sdl_header.step);
    b.getInstallStep().dependOn(&installFile.step);

    //Reference this module through the depenendency in your own build.zig, and import it.
    _ = b.addModule("sdl", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = translate_sdl_header.getOutput(),
    });
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
