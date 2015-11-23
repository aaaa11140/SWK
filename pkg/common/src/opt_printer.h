// **************************************************************************
// File       [ opt_printer.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_OPT_PRINTER_H__
#define __COMMON_OPT_PRINTER_H__

#include <iostream>

namespace CommonNs {

class OptMgr;
class OptPrinter {
public:
    virtual ~OptPrinter() {};

    virtual void print(std::ostream& out=std::cout) const = 0;

protected:
    OptMgr* mgr_;
    OptPrinter(OptMgr* mgr) : mgr_{mgr} {};
};

};

#endif


