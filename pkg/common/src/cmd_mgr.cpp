// **************************************************************************
// File       [ cmd_mgr.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ methods for command manager ]
// Date       [ Version 2.0 2010/04/09 ]
// **************************************************************************

#include <iostream>

#include "cmd_mgr.h"

using namespace std;
using namespace CommonNs;

bool CmdMgr::regCmd(Cmd* cmd) {
    if (cmds_.find(cmd->optmgr.name) != cmds_.end()) // already exist
        return false;
    (cmds_[cmd->optmgr.name]).reset(cmd);
    return true;
}

Cmd* CmdMgr::getCmd(const std::string& name) const {
    CmdIter iter = cmds_.find(name);
    return iter == cmds_.end() ? nullptr : iter->second.get();
}

bool CmdMgr::exec(const string& input) {
    if (input.size() == 0)
        return true;

    cmdHis_.push_back(input);

    // parse input
    string expr = input;
    cmdVarHandler_.expandVar(expr);
    cmdVarHandler_.expandUser(expr);
    vector<string> args;
    args = parse(expr);

    // execute command
    bool redirected = cmdRedirHandler_.redirect(args); // set redirection
    Cmd *cmd = nullptr;
    if (args.size() > 0) {
        CmdIter iter = cmds_.find(args[0]);
        if (iter != cmds_.end())
            cmd = iter->second.get();
        if (!cmd)
            return false;
        result_ = cmd->exec(args);
    }

    // reset stdout
    if (redirected)
        cmdRedirHandler_.reset();

    if (args.size() == 0) {
        result_ = Cmd::SUCCESS;
        return true;
    }

    return cmd ? true : false;
}

vector<string> CmdMgr::parse(const string& input) {
    vector<string> args;

    // discard comment
    size_t end = input.size();
    if (comment_.size() > 0)
        end = input.find(comment_);
    end = end == string::npos ? input.size() : end;

    // split into tokens
    bool inQuote = false;
    string delim = " \t\n>";
    string arg = "";
    for (size_t i = 0; i < end; i++) {
        // characters inside quotation mark are treated as one token
        bool isQuote = input[i] == '"';
        bool zeroLen = arg.size() == 0;
        bool prevBakSlash = arg.size() > 0 && arg[arg.size() - 1] == '\\';
        if (isQuote && (zeroLen || !prevBakSlash))
            inQuote = !inQuote;

        // everything within quotes are counted as one argument
        if (inQuote) {
            arg += input[i];
            continue;
        }

        // the last character of the argument is the quotation mark
        if (isQuote) {
            arg += input[i];
            args.push_back(arg);
            continue;
        }

        // check if the character is delimiter
        if (delim.find(input[i]) != string::npos && arg.size() > 0) {
            args.push_back(arg);
            arg = "";
            continue;
        }

        // handle redirection
        if (input[i] == '>') {
            if (args.size() > 0 && args[args.size() - 1][0] == '>')
                args[args.size() - 1] += ">";
            else
                args.push_back(">");
            continue;
        }

        arg += input[i];
    }

    if (arg.size() > 0)
        args.push_back(arg);

    return move(args);
}


