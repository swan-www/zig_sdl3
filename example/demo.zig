const std = @import("std");
const sdl = @import("sdl");
const sdl_define = @import("sdl_define.zig");

const SDLError = error{
    SDLInitFail,
    AddEventWatchFailure,
    ShadercrossInitFail,
    GPUCreateDeviceFail,
    CreateWindowFail,
    GPUClaimWindowFail,
    InvalidShaderStage,
    FailedToLoadShaderFromDisk,
    FailedToCompileShaderFromSpirv,
	FailedToCreatePipeline,
	AcquireGPUCommandBufferFailed,
	AcquireGPUSwapchainTextureFailed,
};

var ExampleName: []const u8 = "Demo";
var BasePath: ?[*:0]const u8 = null;
var Window: ?*sdl.SDL_Window = null;
var Device: ?*sdl.SDL_GPUDevice = null;
var LeftPressed: bool = false;
var RightPressed: bool = false;
var DownPressed: bool = false;
var UpPressed: bool = false;
var DeltaTime: f32 = 0.0;

var Pipeline: ?*sdl.SDL_GPUGraphicsPipeline = null;
var VertexBuffer: ?*sdl.SDL_GPUBuffer = null;

const PositionColorVertex = extern struct
{
	x : f32,
	y : f32,
	z : f32,
	r : u8,
	g : u8,
	b : u8,
	a : u8,
};

fn LoadShader(
    device: ?*sdl.SDL_GPUDevice,
    shaderFilename: []const u8,
    samplerCount: u32,
    uniformBufferCount: u32,
    storageBufferCount: u32,
    storageTextureCount: u32,
) !*sdl.SDL_GPUShader {
    // Auto-detect the shader stage from the file name for convenience
    var stage: sdl.SDL_GPUShaderStage = 0;
    if (sdl.SDL_strstr(shaderFilename.ptr, ".vert") != null) {
        stage = sdl.SDL_GPU_SHADERSTAGE_VERTEX;
    } else if (sdl.SDL_strstr(shaderFilename.ptr, ".frag") != null) {
        stage = sdl.SDL_GPU_SHADERSTAGE_FRAGMENT;
    } else {
        return SDLError.InvalidShaderStage;
    }

    var fullPathBuff: [256]u8 = std.mem.zeroes([256]u8);
    const fullPath = try std.fmt.bufPrint(&fullPathBuff, "{s}Content/Shaders/Compiled/{s}.spv", .{ BasePath.?, shaderFilename });

    var codeSize: usize = 0;
    const code = sdl.SDL_LoadFile(fullPath.ptr, &codeSize) orelse return SDLError.FailedToLoadShaderFromDisk;
    defer sdl.SDL_free(code);

    const shaderInfo = sdl.SDL_GPUShaderCreateInfo{ .code = @ptrCast(code), .code_size = codeSize, .entrypoint = "main", .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV, .stage = stage, .num_samplers = samplerCount, .num_uniform_buffers = uniformBufferCount, .num_storage_buffers = storageBufferCount, .num_storage_textures = storageTextureCount };
    const shader = sdl.SDL_ShaderCross_CompileGraphicsShaderFromSPIRV(device, &shaderInfo) orelse return SDLError.FailedToCompileShaderFromSpirv;

    return shader;
}

fn Init() !void {
    Device = sdl.SDL_CreateGPUDevice(sdl.SDL_ShaderCross_GetSPIRVShaderFormats(), true, null);
    if (Device == null) {
        return SDLError.GPUCreateDeviceFail;
    }

    const windowFlags = 0;
    Window = sdl.SDL_CreateWindow(ExampleName.ptr, 640, 480, windowFlags);
    if (Window == null) {
        return SDLError.CreateWindowFail;
    }

    if (!sdl.SDL_ClaimWindowForGPUDevice(Device, Window)) {
        return SDLError.GPUClaimWindowFail;
    }

    // Create the shaders
    const vertexShader = try LoadShader(Device, "PositionColor.vert", 0, 0, 0, 0);
    _ = &vertexShader;
    const fragmentShader = try LoadShader(Device, "SolidColor.frag", 0, 0, 0, 0);
    _ = &fragmentShader;

    const pipelineCreateInfo = sdl.SDL_GPUGraphicsPipelineCreateInfo{
		.target_info = .{
			.num_color_targets = 1,
			.color_target_descriptions = &[_]sdl.SDL_GPUColorTargetDescription{
				.{
					.format = sdl.SDL_GetGPUSwapchainTextureFormat(Device, Window),
				},
			},
		},
		.vertex_input_state = sdl.SDL_GPUVertexInputState{
			.num_vertex_buffers = 1,
			.vertex_buffer_descriptions = &[_]sdl.SDL_GPUVertexBufferDescription{
				.{
					.slot = 0,
					.input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
					.instance_step_rate = 0,
					.pitch = @sizeOf(PositionColorVertex),
				}
			},
			.num_vertex_attributes = 2,
			.vertex_attributes = &[_]sdl.SDL_GPUVertexAttribute{
				.{
					.buffer_slot = 0,
					.format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
					.location = 0,
					.offset = 0,
				},
				.{
					.buffer_slot = 0,
					.format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
					.location = 1,
					.offset = @sizeOf(f32) * 3,
				},
			},
		},
		.primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
		.vertex_shader = vertexShader,
		.fragment_shader = fragmentShader,
	};

	Pipeline = sdl.SDL_CreateGPUGraphicsPipeline(Device, &pipelineCreateInfo) orelse return SDLError.FailedToCreatePipeline;

    sdl.SDL_ReleaseGPUShader(Device, vertexShader);
    sdl.SDL_ReleaseGPUShader(Device, fragmentShader);

	VertexBuffer = sdl.SDL_CreateGPUBuffer(
		Device,
		&sdl.SDL_GPUBufferCreateInfo{
			.usage = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
			.size = @sizeOf(PositionColorVertex) * 3,
		}
	);

	const transferBuffer = sdl.SDL_CreateGPUTransferBuffer(
		Device,
		&sdl.SDL_GPUTransferBufferCreateInfo{
			.usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
			.size = @sizeOf(PositionColorVertex) * 3,
		}
	);

	const transferData : [*]PositionColorVertex = @alignCast(@ptrCast(sdl.SDL_MapGPUTransferBuffer(
		Device,
		transferBuffer,
		false
	)));

	transferData[0] = PositionColorVertex{ .x = -1, .y = -1, .z = 0, .r = 255, .g = 0, .b = 0, .a = 255 };
	transferData[1] = PositionColorVertex{ .x = 1, .y = -1, .z = 0, .r = 0, .g = 255, .b = 0, .a = 255 };
	transferData[2] = PositionColorVertex{ .x = 0, .y = 1, .z = 0, .r = 0, .g = 0, .b = 255, .a = 255 };

	sdl.SDL_UnmapGPUTransferBuffer(Device, transferBuffer);

	const uploadCmdBuf : ?*sdl.SDL_GPUCommandBuffer = sdl.SDL_AcquireGPUCommandBuffer(Device);
	const copyPass : ?*sdl.SDL_GPUCopyPass = sdl.SDL_BeginGPUCopyPass(uploadCmdBuf);

	sdl.SDL_UploadToGPUBuffer(
		copyPass,
		&.{
			.transfer_buffer = transferBuffer,
			.offset = 0,
		},
		&.{
			.buffer = VertexBuffer,
			.offset = 0,
			.size = @sizeOf(PositionColorVertex) * 3,
		},
		false
	);

	sdl.SDL_EndGPUCopyPass(copyPass);
	_ = sdl.SDL_SubmitGPUCommandBuffer(uploadCmdBuf);
	sdl.SDL_ReleaseGPUTransferBuffer(Device, transferBuffer);
}

fn Update() !void {}

fn Draw() !void
{
	const cmdbuf = sdl.SDL_AcquireGPUCommandBuffer(Device) orelse return SDLError.AcquireGPUCommandBufferFailed;

	var swapchainTexture : ?*sdl.SDL_GPUTexture = null;
	if (!sdl.SDL_AcquireGPUSwapchainTexture(cmdbuf, Window, &swapchainTexture, null, null)) return SDLError.AcquireGPUSwapchainTextureFailed;

	if (swapchainTexture != null)
	{
		const colorTargetInfo = sdl.SDL_GPUColorTargetInfo{
			.texture = swapchainTexture,
			.clear_color = sdl.SDL_FColor{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
			.load_op = sdl.SDL_GPU_LOADOP_CLEAR,
			.store_op = sdl.SDL_GPU_STOREOP_STORE,
		};

		const renderPass = sdl.SDL_BeginGPURenderPass(cmdbuf,&colorTargetInfo,1,null);

		sdl.SDL_BindGPUGraphicsPipeline(renderPass, Pipeline);
		sdl.SDL_BindGPUVertexBuffers(renderPass, 0, &sdl.SDL_GPUBufferBinding{ .buffer = VertexBuffer, .offset = 0 }, 1);
		sdl.SDL_DrawGPUPrimitives(renderPass, 3, 1, 0, 0);

		sdl.SDL_EndGPURenderPass(renderPass);
	}

	_ = sdl.SDL_SubmitGPUCommandBuffer(cmdbuf);
}

fn Quit() void {
    sdl.SDL_ReleaseGPUGraphicsPipeline(Device, Pipeline);
    sdl.SDL_ReleaseGPUBuffer(Device, VertexBuffer);

    sdl.SDL_ReleaseWindowFromGPUDevice(Device, Window);
    sdl.SDL_DestroyWindow(Window);
    sdl.SDL_DestroyGPUDevice(Device);
}

fn appLifecycleWatcher(_: ?*anyopaque, event: [*c]sdl.SDL_Event) callconv(.C) bool {
    //This callback may be on a different thread, so let's
    //push these events as USER events so they appear
    //in the main thread's event loop.
    //
    //That allows us to cancel drawing before/after we finish
    //drawing a frame, rather than mid-draw (which can crash!).
    //
    if (event.*.type == sdl.SDL_EVENT_DID_ENTER_BACKGROUND) {
        var evt = sdl.SDL_Event{
            .user = .{
                .type = sdl.SDL_EVENT_USER,
                .code = 0,
            },
        };
        _ = sdl.SDL_PushEvent(&evt);
    } else if (event.*.type == sdl.SDL_EVENT_WILL_ENTER_FOREGROUND) {
        var evt = sdl.SDL_Event{
            .user = .{
                .type = sdl.SDL_EVENT_USER,
                .code = 1,
            },
        };
        _ = sdl.SDL_PushEvent(&evt);
    }
    return false;
}

pub fn main() !void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_GAMEPAD)) {
        std.log.err("Failed to initialize SDL: {s}", .{sdl.SDL_GetError()});
        return SDLError.SDLInitFail;
    }

    std.log.info("SDL Initialized!", .{});
    BasePath = sdl.SDL_GetBasePath();
    std.log.info("SDL Base Path: {s}", .{BasePath.?});

    if (!sdl.SDL_AddEventWatch(appLifecycleWatcher, null)) {
        std.log.err("Failed to add SDL watch event: {s}", .{sdl.SDL_GetError()});
        return SDLError.AddEventWatchFailure;
    }
    if (!sdl.SDL_ShaderCross_Init()) {
        std.log.err("Failed to init SDL_ShaderCross: {s}", .{sdl.SDL_GetError()});
        return SDLError.ShadercrossInitFail;
    }

    var gamepad: ?*sdl.SDL_Gamepad = null;
    var canDraw = true;
    var quit = false;
    //var lastTime = 0.0;

    std.log.info("STARTING EXAMPLE: {s}", .{ExampleName});
    try Init();

    while (!quit) {
        var evt = sdl.SDL_Event{
            .type = 0,
        };
        while (sdl.SDL_PollEvent(&evt)) {
            if (evt.type == sdl.SDL_EVENT_QUIT) {
                Quit();
                quit = true;
            } else if (evt.type == sdl.SDL_EVENT_GAMEPAD_ADDED) {
                if (gamepad == null) {
                    gamepad = sdl.SDL_OpenGamepad(evt.gdevice.which);
                }
            } else if (evt.type == sdl.SDL_EVENT_GAMEPAD_REMOVED) {
                if (evt.gdevice.which == sdl.SDL_GetGamepadID(gamepad)) {
                    sdl.SDL_CloseGamepad(gamepad);
                }
            } else if (evt.type == sdl.SDL_EVENT_USER) {
                if (evt.user.code == 0) {
                    if (sdl_define.PLATFORM_GDK) {
                        sdl.SDL_GDKSuspendGPU(Device);
                        canDraw = false;
                        sdl.SDL_GDKSuspendComplete();
                    }
                } else if (evt.user.code == 1) {
                    if (sdl_define.PLATFORM_GDK) {
                        sdl.SDL_GDKResumeGPU(Device);
                        canDraw = true;
                    }
                }
            } else if (evt.type == sdl.SDL_EVENT_KEY_DOWN) {
                if (evt.key.key == sdl.SDLK_D) {} else if (evt.key.key == sdl.SDLK_A) {} else if (evt.key.key == sdl.SDLK_LEFT) {
                    LeftPressed = true;
                } else if (evt.key.key == sdl.SDLK_RIGHT) {
                    RightPressed = true;
                } else if (evt.key.key == sdl.SDLK_DOWN) {
                    DownPressed = true;
                } else if (evt.key.key == sdl.SDLK_UP) {
                    UpPressed = true;
                }
            } else if (evt.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
                if (evt.gbutton.button == sdl.SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER) {} else if (evt.gbutton.button == sdl.SDL_GAMEPAD_BUTTON_LEFT_SHOULDER) {} else if (evt.gbutton.button == sdl.SDL_GAMEPAD_BUTTON_DPAD_LEFT) {
                    LeftPressed = true;
                } else if (evt.gbutton.button == sdl.SDL_GAMEPAD_BUTTON_DPAD_RIGHT) {
                    RightPressed = true;
                } else if (evt.gbutton.button == sdl.SDL_GAMEPAD_BUTTON_DPAD_DOWN) {
                    DownPressed = true;
                } else if (evt.gbutton.button == sdl.SDL_GAMEPAD_BUTTON_DPAD_UP) {
                    UpPressed = true;
                }
            }
        }

        if (quit) {
            break;
        }

        try Update();
        if (canDraw) {
            try Draw();
        }
    }

    sdl.SDL_ShaderCross_Quit();
    sdl.SDL_Quit();
}
