// **************************************************************************
// File       [ opt_basic_printer.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_OPT_BASIC_PRINTER_H__
#define __COMMON_OPT_BASIC_PRINTER_H__

#include "opt_printer.h"

namespace CommonNs {

class OptBasicPrinter : public OptPrinter {
public:
    OptBasicPrinter(OptMgr* mgr) : OptPrinter{mgr} {};
    ~OptBasicPrinter() {};

    virtual void print(std::ostream& out=std::cout) const override;

protected:
    const size_t tabSize_ = 8;
    const size_t winSize_ = 78;

    void nameUsage(std::ostream& out) const;
    void synopsisUsage(std::ostream& out) const;
    void descriptionUsage(std::ostream& out) const;
    void argumentUsage(std::ostream& out) const;
    void optionUsage(std::ostream& out) const;

    // formating printing
    void fitPrint(const std::string& input
        , const size_t& len
        , const bool& indent
        , std::ostream& out) const;
};

};

#endif


