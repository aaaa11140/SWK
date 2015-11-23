// **************************************************************************
// File       [ opt_printer_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/01/03 ]
// **************************************************************************

#ifndef __COMMON_OPT_PRINTER_FACTORY_H__
#define __COMMON_OPT_PRINTER_FACTORY_H__

#include <memory>

#include "opt_printer.h"

namespace CommonNs {

class OptMgr;
class OptPrinterFactory {
public:
    virtual ~OptPrinterFactory() {};
    virtual std::unique_ptr<OptPrinter> create(OptMgr* mgr) const = 0;

protected:
    OptPrinterFactory() {};
};

};

#endif


