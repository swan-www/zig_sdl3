const std = @import("std");
const sdl = @import("sdl");

const sdl_meta = @typeInfo(sdl);

pub const TARGET_OS_MACCATALYST = if(@hasField(sdl, "TARGET_OS_MACCATALYST")) @field(sdl, "TARGET_OS_MACCATALYST") else false;
pub const TARGET_OS_IOS = if(@hasField(sdl, "TARGET_OS_IOS")) @field(sdl, "TARGET_OS_IOS") else false;
pub const TARGET_OS_IPHONE = if(@hasField(sdl, "TARGET_OS_IPHONE")) @field(sdl, "TARGET_OS_IPHONE") else false;
pub const TARGET_OS_TV = if(@hasField(sdl, "TARGET_OS_TV")) @field(sdl, "TARGET_OS_TV") else false;
pub const TARGET_OS_SIMULATOR = if(@hasField(sdl, "TARGET_OS_SIMULATOR")) @field(sdl, "TARGET_OS_SIMULATOR") else false;
pub const TARGET_OS_VISION = if(@hasField(sdl, "TARGET_OS_VISION")) @field(sdl, "TARGET_OS_VISION") else false;

pub const WINAPI_FAMILY_WINRT = if(@hasField(sdl, "WINAPI_FAMILY_WINRT")) @field(sdl, "WINAPI_FAMILY_WINRT") else null;
pub const WINAPI_FAMILY_PHONE = if(@hasField(sdl, "SDL_WINAPI_FAMILY_PHONE")) @field(sdl, "SDL_WINAPI_FAMILY_PHONE") else null;

pub const PLATFORM_AIX = if(@hasField(sdl, "SDL_PLATFORM_AIX")) @field(sdl, "SDL_PLATFORM_AIX") else false;
pub const PLATFORM_HAIKU = if(@hasField(sdl, "SDL_PLATFORM_HAIKU")) @field(sdl, "SDL_PLATFORM_HAIKU") else false;
pub const PLATFORM_BSDI = if(@hasField(sdl, "SDL_PLATFORM_BSDI")) @field(sdl, "SDL_PLATFORM_BSDI") else false;
pub const PLATFORM_FREEBSD = if(@hasField(sdl, "SDL_PLATFORM_FREEBSD")) @field(sdl, "SDL_PLATFORM_FREEBSD") else false;
pub const PLATFORM_HPUX = if(@hasField(sdl, "SDL_PLATFORM_HPUX")) @field(sdl, "SDL_PLATFORM_HPUX") else false;
pub const PLATFORM_IRIX = if(@hasField(sdl, "SDL_PLATFORM_IRIX")) @field(sdl, "SDL_PLATFORM_IRIX") else false;
pub const PLATFORM_LINUX = if(@hasField(sdl, "SDL_PLATFORM_LINUX")) @field(sdl, "SDL_PLATFORM_LINUX") else false;
pub const PLATFORM_ANDROID = if(@hasField(sdl, "SDL_PLATFORM_ANDROID")) @field(sdl, "SDL_PLATFORM_ANDROID") else false;
pub const PLATFORM_NGAGE = if(@hasField(sdl, "SDL_PLATFORM_NGAGE")) @field(sdl, "SDL_PLATFORM_NGAGE") else false;
pub const PLATFORM_UNIX = if(@hasField(sdl, "SDL_PLATFORM_UNIX")) @field(sdl, "SDL_PLATFORM_UNIX") else false;
pub const PLATFORM_APPLE = if(@hasField(sdl, "SDL_PLATFORM_APPLE")) @field(sdl, "SDL_PLATFORM_APPLE") else false;
pub const PLATFORM_TVOS = if(@hasField(sdl, "SDL_PLATFORM_TVOS")) @field(sdl, "SDL_PLATFORM_TVOS") else false;
pub const PLATFORM_VISIONOS = if(@hasField(sdl, "SDL_PLATFORM_VISIONOS")) @field(sdl, "SDL_PLATFORM_VISIONOS") else false;
pub const PLATFORM_IOS = if(@hasField(sdl, "SDL_PLATFORM_IOS")) @field(sdl, "SDL_PLATFORM_IOS") else false;
pub const PLATFORM_MACOS = if(@hasField(sdl, "SDL_PLATFORM_MACOS")) @field(sdl, "SDL_PLATFORM_MACOS") else false;
pub const PLATFORM_EMSCRIPTEN = if(@hasField(sdl, "SDL_PLATFORM_EMSCRIPTEN")) @field(sdl, "SDL_PLATFORM_EMSCRIPTEN") else false;
pub const PLATFORM_NETBSD = if(@hasField(sdl, "SDL_PLATFORM_NETBSD")) @field(sdl, "SDL_PLATFORM_NETBSD") else false;
pub const PLATFORM_OPENBSD = if(@hasField(sdl, "SDL_PLATFORM_OPENBSD")) @field(sdl, "SDL_PLATFORM_OPENBSD") else false;
pub const PLATFORM_OS2 = if(@hasField(sdl, "SDL_PLATFORM_OS2")) @field(sdl, "SDL_PLATFORM_OS2") else false;
pub const PLATFORM_OSF = if(@hasField(sdl, "SDL_PLATFORM_OSF")) @field(sdl, "SDL_PLATFORM_OSF") else false;
pub const PLATFORM_QNXNTO = if(@hasField(sdl, "SDL_PLATFORM_QNXNTO")) @field(sdl, "SDL_PLATFORM_QNXNTO") else false;
pub const PLATFORM_RISCOS = if(@hasField(sdl, "SDL_PLATFORM_RISCOS")) @field(sdl, "SDL_PLATFORM_RISCOS") else false;
pub const PLATFORM_SOLARIS = if(@hasField(sdl, "SDL_PLATFORM_SOLARIS")) @field(sdl, "SDL_PLATFORM_SOLARIS") else false;
pub const PLATFORM_CYGWIN = if(@hasField(sdl, "SDL_PLATFORM_CYGWIN")) @field(sdl, "SDL_PLATFORM_CYGWIN") else false;
pub const PLATFORM_WINDOWS = if(@hasField(sdl, "SDL_PLATFORM_WINDOWS")) @field(sdl, "SDL_PLATFORM_WINDOWS") else false;

pub const PLATFORM_WINGDK = if(@hasField(sdl, "SDL_PLATFORM_WINGDK")) @field(sdl, "SDL_PLATFORM_WINGDK") else false;
pub const PLATFORM_XBOXONE = if(@hasField(sdl, "SDL_PLATFORM_XBOXONE")) @field(sdl, "SDL_PLATFORM_XBOXONE") else false;
pub const PLATFORM_XBOXSERIES = if(@hasField(sdl, "SDL_PLATFORM_XBOXSERIES")) @field(sdl, "SDL_PLATFORM_XBOXSERIES") else false;
pub const PLATFORM_WIN32 = if(@hasField(sdl, "SDL_PLATFORM_WIN32")) @field(sdl, "SDL_PLATFORM_WIN32") else false;
pub const PLATFORM_GDK = if(@hasField(sdl, "SDL_PLATFORM_GDK")) @field(sdl, "SDL_PLATFORM_GDK") else false;
pub const PLATFORM_PSP = if(@hasField(sdl, "SDL_PLATFORM_PSP")) @field(sdl, "SDL_PLATFORM_PSP") else false;
pub const PLATFORM_PS2 = if(@hasField(sdl, "SDL_PLATFORM_PS2")) @field(sdl, "SDL_PLATFORM_PS2") else false;
pub const PLATFORM_VITA = if(@hasField(sdl, "SDL_PLATFORM_VITA")) @field(sdl, "SDL_PLATFORM_VITA") else false;
pub const PLATFORM_3DS = if(@hasField(sdl, "SDL_PLATFORM_3DS")) @field(sdl, "SDL_PLATFORM_3DS") else false;