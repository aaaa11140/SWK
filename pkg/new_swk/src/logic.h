// **************************************************************************
// File       [ logic.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/08/19 ]
// **************************************************************************

#ifndef __CORE_LOGIC_H__
#define __CORE_LOGIC_H__

namespace CoreNs {

typedef unsigned long ParaV;
const   unsigned long ParaL = 0x0000000000000000;
const   unsigned long ParaH = 0x1111111111111111;

typedef pair<ParaV, ParaV> ParaTwoV;
const   unsigned long ParaTwoL = pair<ParaV, ParaV>(ParaH, ParaL);
const   unsigned long ParaTwoH = pair<ParaV, ParaV>(ParaL, ParaH);
const   unsigned long ParaTwoX = pair<ParaV, ParaV>(ParaL, ParaL);

};

#endif


