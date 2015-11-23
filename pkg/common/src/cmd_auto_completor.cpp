// **************************************************************************
// File       [ cmd_auto_completor.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/01 ]
// **************************************************************************

#include <sys/stat.h>   // directory testing
#include <sys/types.h>  // file redirection
#include <pwd.h>        // user home path
#include <unistd.h>     // current user ID
#include <dirent.h>     // getting directory contents
#include <cstdlib>      // getting environment variable

#include "cmd_auto_completor.h"

using namespace std;
using namespace CommonNs;

vector<string> CmdAutoCompletor::complete(CmdMgr* mgr
    , string& input
    , size_t& csrpos)
{
    mgr_ = mgr;

    // parse input
    parse(input, csrpos);

    // find candidates
    vector<string> cddts;
    if (iscmd_)
        cddts = completeCmd();
    else if (isopt_)
        cddts = completeOpt();
    else if (isvar_)
        cddts = completeVar();
    else
        cddts = completeFile();

    // find common string
    string cmn = cddts.size() > 0 ? cddts[0] : "";
    for (size_t i = 1; i < cddts.size(); ++i) {
        size_t pos = commonPos(cmn, cddts[i]);
        cmn = cmn.substr(0, pos);
    }

    // update input and cursor position
    if (cddts.size() > 0) {
        input.insert(csrpos, cmn.substr(prefix_.size()));
        csrpos += cmn.size() - prefix_.size();
    }
    if (cddts.size() == 1) {
        if (!isfile_ || (isfile_ && cmn[cmn.size() - 1] != '/')) {
            input.insert(csrpos, " ");
            csrpos++;
        }
        if (isvar_ && tail_.size() > 1 && tail_[1] == '{') {
            input.insert(csrpos - 1, "}");
            csrpos++;
        }
    }

    return move(cddts);
}

void CmdAutoCompletor::parse(const std::string& input, const size_t& csrpos) {
    nTokens_ = 0;
    head_    = "";
    tail_    = "";
    prefix_  = "";
    isdelim_ = false;
    iscmd_   = false;
    isopt_   = false;
    isvar_   = false;
    isfile_  = false;

    // check if the cursor is pointing at a delimiter
    string delim{" \"="};
    if (input.size() > 0 && delim.find(input[csrpos - 1]) != string::npos)
        isdelim_ = true;

    // find head token and tail token
    string csrstr = input.substr(0, csrpos);
    size_t prev = 0;
    size_t curr = 0;
    size_t next = 0;
    do {
        curr = csrstr.find_first_not_of(delim, next);
        if (curr == string::npos)
            break;
        next = csrstr.find_first_of(delim, curr);
        if (nTokens_ == 0)
            head_ = csrstr.substr(curr, next - curr);
        nTokens_++;
        prev = curr;
    } while (next != string::npos);
    tail_ = csrstr.substr(prev, next - prev);

    size_t pos = tail_.find_last_of('/');;
    if (pos != string::npos && pos < tail_.size()
        && tail_[pos + 1] == '$' && tail_[tail_.size() - 1] != '}') {
        tail_ = tail_.substr(pos + 1);
    }


    // find out which part is to be completed
    iscmd_ = nTokens_ == 0 || (nTokens_ == 1 && !isdelim_);
    isopt_ = nTokens_ > 1 && tail_[0] == '-' && !isdelim_;
    isvar_ = nTokens_ > 1 && tail_[0] == '$' && !isdelim_;
    isfile_ = !iscmd_ && !isopt_ && !isvar_;

    // find prefix
    if (isdelim_)
        prefix_ = "";
    else if (tail_.size() > 0 && tail_[0] == '-') {
        prefix_ = tail_.substr(1);
        if (tail_.size() > 1 && tail_[1] == '-')
            prefix_ = tail_.substr(2);
    }
    else if (tail_.size() > 0 && tail_[0] == '$') {
        prefix_ = tail_.substr(1);
        if (tail_.size() > 1 && tail_[1] == '{')
            prefix_ = tail_.substr(2);
    }
    else if ((pos = tail_.find_last_of('/')) != string::npos) {
        prefix_ = tail_.substr(pos + 1);
    }
    else {
        prefix_ = tail_;
    }

}

vector<string> CmdAutoCompletor::completeCmd() {
    vector<string> cddts;
    for (auto it = mgr_->cmdBegin(); it != mgr_->cmdEnd(); ++it) {
        size_t len = prefix_.size();
        if (prefix_.compare(0, len, it->first, 0, len) == 0)
            cddts.push_back(it->first);
    }
    return move(cddts);
}

vector<string> CmdAutoCompletor::completeOpt() {
    vector<string> cddts;
    bool completeLong = tail_.size() > 1 && tail_[1] == '-';
    Cmd* cmd = mgr_->getCmd(head_);
    if (!cmd)
        return move(cddts);
    for (size_t i = 0; i < cmd->optmgr.nOpts(); ++i) {
        const Opt* opt = cmd->optmgr.getOpt(i);
        for (size_t j = 0; j < opt->nFlags(); ++j) {
            const string flag = opt->getFlag(j);
            bool islong = flag.size() > 1;
            if (!completeLong)
                continue;
            size_t len = prefix_.size();
            if (!islong && prefix_.size() == 0)
                cddts.push_back(flag);
            else if (islong && prefix_.compare(0, len, flag, 0, len) == 0)
                cddts.push_back(flag);
        }
    }
    return move(cddts);
}

vector<string> CmdAutoCompletor::completeVar() {
    vector<string> cddts;
    CmdVarHandler* handler = mgr_->cmdVarHandler();
    for (auto it = handler->varBegin(); it != handler->varEnd(); ++it) {
        string name = it->first;
        size_t len = prefix_.size();
        if (prefix_.compare(0, len, name, 0, len) == 0)
            cddts.push_back(name);
    }
    return move(cddts);
}

vector<string> CmdAutoCompletor::completeFile() {
    vector<string> cddts;
    string path = isdelim_ ? "./" : "./" + tail_;
    CmdVarHandler* handler = mgr_->cmdVarHandler();
    handler->expandVar(path);
    handler->expandUser(path);

    size_t sep = path.find_last_of('/');
    string dirname = path.substr(0, sep);
    string prefix = path.substr(sep + 1);

    // find directory entries
    vector<string> entries;
    DIR *dir;
    dirent *ent;
    if ((dir = opendir(dirname.c_str())) != NULL) {
        struct stat fstat;
        while ((ent = readdir(dir)) != NULL) {
            string entry = string(ent->d_name);
            string absname = dirname + "/" + entry;
            if (stat(absname.c_str(), &fstat) == 0)
                if (S_ISDIR(fstat.st_mode) != 0)
                    entry += "/";
            entries.push_back(entry);
        }
        closedir(dir);
    }

    // find candidates
    for (size_t i = 0; i < entries.size(); ++i) {
        string entry = entries[i];
        size_t len = prefix.size();
        if (prefix.compare(0, len, entry, 0, len) == 0)
            cddts.push_back(entry);
    }
    return move(cddts);
}


