// **************************************************************************
// File       [ opt_parser.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_OPT_PARSER_H___
#define __COMMON_OPT_PARSER_H___

#include <string>
#include <vector>


namespace CommonNs {

class OptMgr;
class OptParser {
public:
    virtual ~OptParser() {};

    virtual bool parse(int argc, char** argv) = 0;
    virtual bool parse(const std::vector<std::string>& args) = 0;
    virtual size_t nParsedArgs() const = 0;
    virtual const std::string& getParsedArg(const size_t& i) const = 0;
    virtual bool getParsedOpt(const std::string& f) const = 0;
    virtual const std::string& getParsedValue(const std::string& f) const = 0;

protected:
    OptMgr* mgr_;
    OptParser(OptMgr* mgr) : mgr_{mgr} {};
};

};

#endif


