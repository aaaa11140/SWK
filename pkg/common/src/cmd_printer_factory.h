// **************************************************************************
// File       [ cmd_printer_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/03/19 ]
// **************************************************************************

#ifndef __COMMON_CMD_PRINTER_FACTORY_H__
#define __COMMON_CMD_PRINTER_FACTORY_H__

#include <memory>

#include "cmd_printer.h"

namespace CommonNs {

class CmdMgr;
class CmdPrinterFactory {
public:
    virtual
    ~CmdPrinterFactory() {};

    virtual
    std::unique_ptr<CmdPrinter> create(CmdMgr* mgr) const = 0;

protected:
    CmdPrinterFactory() {};
};

};

#endif


