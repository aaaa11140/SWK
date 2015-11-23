// **************************************************************************
// File       [ opt_parser_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/01/03 ]
// **************************************************************************

#ifndef __COMMON_OPT_PARSER_FACTORY_H__
#define __COMMON_OPT_PARSER_FACTORY_H__

#include <memory>

#include "opt_parser.h"

namespace CommonNs {

class OptMgr;
class OptParserFactory {
public:
    virtual ~OptParserFactory() {};
    virtual std::unique_ptr<OptParser> create(OptMgr* mgr) const = 0;

protected:
    OptParserFactory() {};
};

};

#endif


