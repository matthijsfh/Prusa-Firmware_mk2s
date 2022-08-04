#pragma once

#ifndef UNITTEST
#include "Marlin.h"

// Beware - before changing this prefix, think twice
// you'd need to change appmain.cpp app_marlin_serial_output_write_hook
// and MMU2::ReportError + MMU2::ReportProgress
static constexpr char mmu2Magic[] PROGMEM = "MMU2:";

#define SERIAL_MMU2() { serialprintPGM(mmu2Magic); }

#define MMU2_ECHO_MSG(S) do{ SERIAL_ECHO_START; SERIAL_MMU2(); SERIAL_ECHO(S); }while(0)
#define MMU2_ERROR_MSG(S) do{ SERIAL_ERROR_START; SERIAL_MMU2(); SERIAL_ECHO(S); }while(0)

#else // #ifndef UNITTEST

#define MMU2_ECHO_MSG(S) /* */
#define MMU2_ERROR_MSG(S) /* */
#define SERIAL_ECHO(S) /* */
#define SERIAL_ECHOLN(S) /* */

#endif // #ifndef UNITTEST
