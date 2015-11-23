// **************************************************************************
// File       [ opt_basic_printer_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/01/03 ]
// **************************************************************************

#ifndef __COMMON_OPT_BASIC_PRINTER_FACTORY_H__
#define __COMMON_OPT_BASIC_PRINTER_FACTORY_H__

#include "opt_printer_factory.h"
#include "opt_basic_printer.h"

namespace CommonNs {

class OptBasicPrinterFactory : public OptPrinterFactory {
public:
    OptBasicPrinterFactory() {};
    ~OptBasicPrinterFactory() {};

    std::unique_ptr<OptPrinter> create(OptMgr* mgr) const {
        return std::unique_ptr<OptPrinter> (new OptBasicPrinter(mgr));
    }
};

};

#endif


