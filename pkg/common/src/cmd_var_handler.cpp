// **************************************************************************
// File       [ cmd_var_handler.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/03/17 ]
// **************************************************************************

#include <pwd.h>    // user home path
#include <unistd.h> // current user ID
#include <cstdlib>  // environment variables

#include "cmd_var_handler.h"

using namespace std;
using namespace CommonNs;

void CmdVarHandler::expandVar(string& input) {
    size_t pos = 0;
    while ((pos = input.find('$', pos)) != string::npos) {
        // find variables
        size_t start = pos + 1;  // start of the variable
        if (start < input.size() && input[start] == '{')
            start++;
        size_t end = start;
        while (end < input.size()) {  // find the end of the variable
            if (end == start && !isVarFirstCh(input[end]))
                break;
            if (end > start && !isVarRestOfCh(input[end]))
                break;
            end++;
        }
        string var = input.substr(start, end - start);

        // lookup variable
        const char* value = nullptr;
        if (getVar(var))
            value = getVar(var)->c_str();
        if (!value)
            value = getenv(var.c_str());

        // replace
        string replace = value ? string(value) : "";
        if (end < input.size() && input[end] == '}')
            end++;
        input.replace(pos, end - pos, replace);
    }
}

void CmdVarHandler::expandUser(string& input) {
    size_t pos = 0;
    while ((pos = input.find('~', pos)) != string::npos) {
        // find user name
        size_t start = pos + 1;
        size_t end = start;
        while (end < input.size()) {  // find the end of the username
            if (end == start && !isVarFirstCh(input[end]))
                break;
            if (end > start && !isVarRestOfCh(input[end]))
                break;
            end++;
        }

        // lookup user
        struct passwd* profile = nullptr;
        if (end - pos == 1) // empty
            profile = getpwuid(getuid());
        else
            profile = getpwnam(input.substr(pos + 1, end - pos - 1).c_str());

        // replace
        if (profile)
            input.replace(pos, end - pos, string(profile->pw_dir));
        else
            pos = end;
    }
}

bool CmdVarHandler::regVar(const std::string& var, const std::string& value) {
    if (!isVar(var))  // illegal naming
        return false;
    if (vars_.find(var) != vars_.end())  // already exists
        return false;
    vars_[var] = value;
    return true;
}

const std::string* const CmdVarHandler::getVar(const std::string& var) const {
    VarIter iter = vars_.find(var);
    return iter == vars_.end() ? nullptr : &(iter->second);
}

CmdVarHandler::VarIter CmdVarHandler::varBegin() const {
    return vars_.begin();
}

CmdVarHandler::VarIter CmdVarHandler::varEnd() const {
    return vars_.end();
}


bool CmdVarHandler::isVar(const std::string& var) {
    for (size_t i = 0; i < var.size(); ++i) {
        if (i == 0 && !isVarFirstCh(var[i]))
            return false;
        else if (i > 0 && !isVarRestOfCh(var[i]))
            return false;
    }
    return true;
}

bool CmdVarHandler::isVarFirstCh(const char& ch) {
    return isalpha(ch) || ch == '_';
}

bool CmdVarHandler::isVarRestOfCh(const char& ch) {
    return isalnum(ch) || ch == '_';
}

