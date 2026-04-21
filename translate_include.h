#ifndef TRANSLATE_INCLUDE_H
#define TRANSLATE_INCLUDE_H

#if defined(_MSC_VER)
#ifndef SIZE_MAX
    #ifdef _WIN64
        #define SIZE_MAX 0xffffffffffffffffull
    #else
        #define SIZE_MAX 0xffffffffu
    #endif
#endif
#endif

#include <SDL3/SDL.h>

#ifdef ZIG_SDL_SHADERCROSS
#include <SDL3_shadercross/SDL_shadercross.h>
#endif //ZIG_SDL_SHADERCROSS

#endif //TRANSLATE_INCLUDE_H