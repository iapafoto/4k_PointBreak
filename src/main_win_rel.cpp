#include <windows.h>
#include <GL/gl.h>
#include <mmsystem.h>
#include <mmreg.h>
#include "config.h"
#include "glext.h"
#include "fragment_shader.inl"
#include "song.h"


static MMTIME MMTime = { TIME_SAMPLES, 0 };

#ifndef SOUND_DISABLED

static SUsample lpSoundBuffer[SU_BUFFER_LENGTH];


HWAVEOUT	hWaveOut;

#pragma data_seg(".wavefmt")
WAVEFORMATEX WaveFMT =
{
#ifdef SU_SAMPLE_FLOAT	
    WAVE_FORMAT_IEEE_FLOAT,
#else
//    WAVE_FORMAT_PCM,
#endif		
    SU_CHANNEL_COUNT, // channels
    SU_SAMPLE_RATE, // samples per sec
    SU_SAMPLE_RATE * SU_SAMPLE_SIZE * SU_CHANNEL_COUNT, // bytes per sec
    SU_SAMPLE_SIZE * SU_CHANNEL_COUNT, // block alignment;
    SU_SAMPLE_SIZE * 8, // bits per sample
    0 // extension not needed
};

#pragma data_seg(".wavehdr")
WAVEHDR WaveHDR = { (LPSTR)lpSoundBuffer, SU_BUFFER_LENGTH * SU_SAMPLE_SIZE, 0,0,0,0,0,0 };

#endif // SOUND_DISABLED


static const PIXELFORMATDESCRIPTOR pfd = {
    sizeof(PIXELFORMATDESCRIPTOR), 1, PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER, PFD_TYPE_RGBA,
    32, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 32, 0, 0, PFD_MAIN_PLANE, 0, 0, 0, 0 };

#pragma data_seg(".devmode")
static DEVMODE screenSettings = { {0},
    #if _MSC_VER < 1400
    0,0,148,0,0x001c0000,{0},0,0,0,0,0,0,0,0,0,{0},0,32,XRES,YRES,0,0,      // Visual C++ 6.0
    #else
    0,0,156,0,0x001c0000,{0},0,0,0,0,0,{0},0,32,XRES,YRES,{0}, 0,           // Visual Studio 2005
    #endif
    #if(WINVER >= 0x0400)
    0,0,0,0,0,0,
    #if (WINVER >= 0x0500) || (_WIN32_WINNT >= 0x0400)
    0,0
    #endif
    #endif
};

#ifdef __cplusplus
extern "C"
{
#endif
    int  _fltused = 0;
#ifdef __cplusplus
}
#endif


#pragma code_seg(".entry")
void entrypoint(void)
{
    ChangeDisplaySettings(&screenSettings, CDS_FULLSCREEN); // 20 octets a peu pres

    ShowCursor(0); // 5 octets
    HDC hDC = GetDC(CreateWindow((LPCSTR)0xC018, 0, WS_POPUP | WS_VISIBLE, 0, 0, XRES, YRES, 0, 0, 0, 0));
    SetPixelFormat(hDC, ChoosePixelFormat(hDC, &pfd), &pfd);

    //------------------

       // initalize opengl
    wglMakeCurrent(hDC, wglCreateContext(hDC));

    int fsid = ((PFNGLCREATESHADERPROGRAMVPROC)wglGetProcAddress("glCreateShaderProgramv"))(GL_FRAGMENT_SHADER, 1, &fragment_shader_glsl);
    ((PFNGLUSEPROGRAMPROC)wglGetProcAddress("glUseProgram"))(fsid);

#ifndef SOUND_DISABLED
    // thx to xTr1m/blu-flame for providing a smarter and smaller way to create the thread :)
    CreateThread(0, 0, (LPTHREAD_START_ROUTINE)su_render_song, lpSoundBuffer, 0, 0);
    waveOutOpen(&hWaveOut, WAVE_MAPPER, &WaveFMT, NULL, 0, CALLBACK_NULL);
    waveOutPrepareHeader(hWaveOut, &WaveHDR, sizeof(WaveHDR));
    waveOutWrite(hWaveOut, &WaveHDR, sizeof(WaveHDR));
#endif  

    int sample;

    // play intro
    auto pfnUniform1f = (PFNGLPROGRAMUNIFORM1FPROC)wglGetProcAddress("glProgramUniform1f");

    do {
#ifndef SOUND_DISABLED
        waveOutGetPosition(hWaveOut, &MMTime, sizeof(MMTIME));
        // ---------------------------------------------------------------------
        // Calcul de l'indice de l'échantillon dans le buffer audio
        sample = (int)MMTime.u.sample;
#else
        sample = 10;
#endif

        // TODO mettre la date dans le meme param
        //((PFNGLPROGRAMUNIFORM1FPROC)wglGetProcAddress("glProgramUniform1f"))(fsid, 0, sample / (float)SU_SAMPLE_RATE);
        pfnUniform1f(fsid, 0, sample / (float)SU_SAMPLE_RATE);
        // Afficher le résultat dans le shader GLSL
        glRects(-1, -1, 1, 1);
        wglSwapLayerBuffers(hDC, WGL_SWAP_MAIN_PLANE);
        PeekMessage(0, 0, 0, 0, PM_REMOVE);

    } while (!GetAsyncKeyState(VK_ESCAPE) && sample < SU_LENGTH_IN_SAMPLES);

    ExitProcess(0);
}