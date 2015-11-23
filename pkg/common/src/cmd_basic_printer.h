// **************************************************************************
// File       [ cmd_basic_printer.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/06/30 created ]
// **************************************************************************

#ifndef __COMMON_CMD_BASIC_PRINTER_H__
#define __COMMON_CMD_BASIC_PRINTER_H__

#include <iostream>

#include "cmd_printer.h"

namespace CommonNs {

class CmdBasicPrinter : public CmdPrinter {
public:
    CmdBasicPrinter(CmdMgr* mgr) : CmdPrinter(mgr) {};
    ~CmdBasicPrinter() {};

    void print(std::ostream& out=std::cout) const override;
};

};

#endif


