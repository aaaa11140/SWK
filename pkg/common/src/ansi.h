// **************************************************************************
// File       [ ansi.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2013/11/19 ]
// **************************************************************************

#ifndef __COMMON_ANSI_H__
#define __COMMON_ANSI_H__

namespace CommonNs {

// ANSI colors
const char* const ANSI_RESET  = "\033[0m";
const char* const ANSI_BLACK  = "\033[30m";
const char* const ANSI_RED    = "\033[31m";
const char* const ANSI_GREEN  = "\033[32m";
const char* const ANSI_YELLOW = "\033[33m";
const char* const ANSI_BLUE   = "\033[34m";
const char* const ANSI_PURPLE = "\033[35m";
const char* const ANSI_CYAN   = "\033[36m";
const char* const ANSI_WHITE  = "\033[37m";

// ANSI text effect
const char* const ANSI_BOLD   = "\033[1m";
const char* const ANSI_UNDER  = "\033[4m";

// Special keys
const char* const ANSI_ARROW_UP    = "\033[A";
const char* const ANSI_ARROW_DOWN  = "\033[B";
const char* const ANSI_ARROW_RIGHT = "\033[C";
const char* const ANSI_ARROW_LEFT  = "\033[D";
const char* const ANSI_HOME        = "\033[1~";
const char* const ANSI_INSERT      = "\033[2~";
const char* const ANSI_DELETE      = "\033[3~";
const char* const ANSI_END         = "\033[4~";
const char* const ANSI_PAGE_UP     = "\033[5~";
const char* const ANSI_PAGE_DOWN   = "\033[6~";

};

#endif


