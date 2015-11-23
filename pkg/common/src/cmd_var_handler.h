// **************************************************************************
// File       [ cmd_var_handler.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/03/12 ]
// **************************************************************************

#ifndef __COMMON_CMD_VAR_HANDLER_H__
#define __COMMON_CMD_VAR_HANDLER_H__

#include <map>
#include <string>

namespace CommonNs {

class CmdVarHandler {
public:
    CmdVarHandler() {};
    ~CmdVarHandler() {};

    typedef std::map<std::string, std::string> VarMap;
    typedef VarMap::const_iterator VarIter;

    // register variables
    bool regVar(const std::string& var, const std::string& value);
    const std::string* const getVar(const std::string& var) const;
    VarIter varBegin() const;
    VarIter varEnd() const;

    // variable naming checking
    bool isVar(const std::string& var);
    bool isVarFirstCh(const char& ch);
    bool isVarRestOfCh(const char& ch);

    // parsing
    void expandVar(std::string& input);
    void expandUser(std::string& input);

private:
    VarMap vars_;

};

};

#endif


