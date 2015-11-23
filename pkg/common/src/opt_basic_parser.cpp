// **************************************************************************
// File       [ opt_basic_parser.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#include <iostream>
#include <cstring>

#include "opt_mgr.h"
#include "opt_basic_parser.h"

using namespace std;
using namespace CommonNs;

bool OptBasicParser::parse(const vector<string>& args) {
    int argc = args.size();
    char **argv = new char*[argc];
    for (int i = 0; i < argc; ++i)
        argv[i] = strdup(args[i].c_str());
    bool res = parse(argc, argv);
    for (int i = 0; i < argc; ++i)
        delete [] argv[i];
    delete [] argv;
    return res;
}

bool OptBasicParser::parse(int argc, char **argv) { //{{{

    // clear previous parsed data
    parsedArgs_.clear();
    parsedOpts_.clear();
    parsedValues_.clear();
    parsedOpts_.resize(mgr_->nOpts(), false);
    parsedValues_.resize(mgr_->nOpts(), "");

    bool endOfOpt = false;
    for (int i = 0; i < argc; ++i) {
        // options
        if (!endOfOpt && strlen(argv[i]) >= 2 && argv[i][0] == '-') {
            if (argv[i][1] != '-') {
                if(!parseShortFlags(argc, argv, i))
                    return false;
            }
            else {
                if (strlen(argv[i]) == 2)
                    endOfOpt = true;
                else if (!parseLongFlags(argc, argv, i))
                    return false;
            }
        }
        else // arguments
            parsedArgs_.push_back(argv[i]);
    }
    return true;
} //}}}
//{{{ bool OptBasicParser::parseShortFlags()
bool OptBasicParser::parseShortFlags(int argc, char **argv, int &i) {
    char *sflags = &argv[i][1]; // short flags
    for (char *ch = sflags; ch < sflags + strlen(sflags); ch++) {

        // check flag
        string flag(1, *ch);
        size_t j = 0;
        bool found = false;
        for ( ; !found && j < mgr_->nOpts(); ++j) {
            for (size_t k = 0; k < mgr_->getOpt(j)->nFlags(); ++k) {
                if (flag == mgr_->getOpt(j)->getFlag(k)) {
                    found = true;
                    break;
                }
            }
            if (found)
                break;
        }
        if (!found)
            return false;

        // check option requirement
        bool lastFlag = ch == &sflags[strlen(sflags) - 1];
        bool nextIsArg = i + 1 < argc && argv[i + 1][0] != '-';
        parsedOpts_[j] = true;
        if (mgr_->getOpt(j)->type() != Opt::BOOL) { // STRREQ and STROPT
            if (!lastFlag) {
                parsedValues_[j] = string(ch + 1);
                break;
            }
            else if (lastFlag && nextIsArg) {
                parsedValues_[j] = string(argv[i + 1]);
                i++;
                break;
            }
            else if (mgr_->getOpt(j)->type() == Opt::STROPT) // no values
                ;
            else {
                parsedOpts_[j] = false;
                return false;
            }
        }
    }

    return true;
} //}}}
//{{{ bool OptBasicParser::parseLongFlags()
bool OptBasicParser::parseLongFlags(int argc, char **argv, int &i) {
    // check equal sign assignment
    char *lflags = &argv[i][2]; // long flag
    char *equ = strchr(lflags, '=');
    int pos = equ ? equ - lflags : strlen(lflags);
    string flag = string(lflags, pos);

    // check flag
    size_t j = 0;
    bool found = false;
    for ( ; !found && j < mgr_->nOpts(); ++j) {
        for (size_t k = 0; k < mgr_->getOpt(j)->nFlags(); ++k) {
            if (flag == mgr_->getOpt(j)->getFlag(k)) {
                found = true;
                break;
            }
        }
        if (found)
            break;
    }
    if (!found)
        return false;

    // check option requirement
    bool hasEqual = equ != NULL;
    bool nextIsArg = i + 1 < argc && argv[i + 1][0] != '-';
    parsedOpts_[j] = true;
    if (mgr_->getOpt(j)->type() != Opt::BOOL) { // STRREQ and STROPT
        if (hasEqual)
            parsedValues_[j] = string(equ + 1);
        else if (!hasEqual && nextIsArg) {
            parsedValues_[j] = string(argv[i + 1]);
            i++;
        }
        else if (mgr_->getOpt(j)->type() == Opt::STROPT) // no values
            ;
        else {
            parsedOpts_[j] = false;
            return false;
        }
    }
    return true;
} //}}}
//{{{ bool OptBasicParser::getParsedOpt()
bool OptBasicParser::getParsedOpt(const string& f) const {
    if (!mgr_)
        return false;
    for (size_t i = 0; i < mgr_->nOpts(); ++i)
        for (size_t j = 0; j < mgr_->getOpt(i)->nFlags(); ++j)
            if (f == mgr_->getOpt(i)->getFlag(j))
                return parsedOpts_[i];
    return false;
} //}}}
//{{{ const string& OptBasicParser::getParsedValue()
const string& OptBasicParser::getParsedValue(const string& f) const {
    if (!mgr_)
        return move(string(""));
    for (size_t i = 0; i < mgr_->nOpts(); ++i)
        for (size_t j = 0; j < mgr_->getOpt(i)->nFlags(); ++j)
            if (f == mgr_->getOpt(i)->getFlag(j))
                return parsedValues_[i];
    return move(string(""));
} //}}}

