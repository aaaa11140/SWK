// **************************************************************************
// File       [ opt_basic_parser.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __OPT_BASIC_PARSER_H__
#define __OPT_BASIC_PARSER_H__

#include <vector>
#include <string>

#include "opt_parser.h"

namespace CommonNs {

class OptMgr;

class OptBasicParser : public OptParser {
public:
    OptBasicParser(OptMgr* mgr) : OptParser{mgr} {};
    ~OptBasicParser() {};

    virtual bool parse(int argc, char** argv) override;
    virtual bool parse(const std::vector<std::string>& args) override;
    virtual size_t nParsedArgs() const override;
    virtual const std::string&
        getParsedArg(const size_t& i) const override;
    virtual bool getParsedOpt(const std::string& f) const override;
    virtual const std::string&
        getParsedValue(const std::string& f) const override;

protected:
    bool parseShortFlags(int argc, char **argv, int &i);
    bool parseLongFlags(int argc, char **argv, int &i);
    std::vector<std::string> parsedArgs_;
    std::vector<bool>        parsedOpts_;
    std::vector<std::string> parsedValues_;
};


inline size_t OptBasicParser::nParsedArgs() const {
    return parsedArgs_.size();
}

inline const std::string& OptBasicParser::getParsedArg(const size_t &i) const {
    return parsedArgs_[i];
}

};

#endif


