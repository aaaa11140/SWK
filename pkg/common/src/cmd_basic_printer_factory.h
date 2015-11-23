// **************************************************************************
// File       [ cmd_basic_printer_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/18 ]
// **************************************************************************

#ifndef __COMMON_CMD_BASIC_PRINTER_FACTORY_H__
#define __COMMON_CMD_BASIC_PRINTER_FACTORY_H__

#include "cmd_basic_printer.h"
#include "cmd_printer_factory.h"

namespace CommonNs {

class CmdBasicPrinterFactory : public CmdPrinterFactory {
public:
    CmdBasicPrinterFactory() {};
    ~CmdBasicPrinterFactory() {};

    std::unique_ptr<CmdPrinter> create(CmdMgr* mgr) const override {
        return std::unique_ptr<CmdPrinter> (new CmdBasicPrinter(mgr));
    }
};

};

#endif


