// **************************************************************************
// File       [ opt_basic_parser_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/01/03 ]
// **************************************************************************

#ifndef __COMMON_OPT_BASIC_PARSER_FACTORY_H__
#define __COMMON_OPT_BASIC_PARSER_FACTORY_H__

#include "opt_basic_parser.h"
#include "opt_parser_factory.h"

namespace CommonNs {

class OptBasicParserFactory : public OptParserFactory {
public:
    OptBasicParserFactory() {};
    ~OptBasicParserFactory() {};

    std::unique_ptr<OptParser> create(OptMgr* mgr) const override {
        return std::unique_ptr<OptParser> (new OptBasicParser(mgr));
    }
};

};

#endif


