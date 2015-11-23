// **************************************************************************
// File       [ cmd_redir_handler.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/01 ]
// **************************************************************************

#include <unistd.h> // file redirection

#include "cmd_redir_handler.h"

using namespace std;
using namespace CommonNs;

bool CmdRedirHandler::redirect(vector<string>& args) {
    bool redirected = false;
    if (args.size() >= 2 && args[args.size() - 2] == ">") {
        if (set(args[args.size() - 1], "w"))
            redirected = true;
    }
    else if (args.size() >= 2 && args[args.size() - 2] == ">>") {
        if (set(args[args.size() - 1], "a"))
            redirected = true;
    }
    if (redirected)
        args.erase(args.end() - 2, args.end());
    return redirected;
}

bool CmdRedirHandler::set(const string fname, const string mode)
{
    fd_ = dup(fileno(stdout));
    fgetpos(stdout, &fpos_);
    // check file
    FILE *fptr = fopen(fname.c_str(), mode.c_str());
    if (!fptr)
        return false;
    fclose(fptr);

    // redirect
    if (!freopen(fname.c_str(), mode.c_str(), stdout))
        return false;

    return true;
}

void CmdRedirHandler::reset() {
    fflush(stdout);
    dup2(fd_, fileno(stdout));
    close(fd_);
    clearerr(stdout);
    fsetpos(stdout, &fpos_);
}

