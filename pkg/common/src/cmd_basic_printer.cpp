// **************************************************************************
// File       [ cmd_basic_printer.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/18 ]
// **************************************************************************

#include <iomanip>
#include <sys/ioctl.h> // getting window size

#include "cmd_mgr.h"
#include "cmd_basic_printer.h"

using namespace std;
using namespace CommonNs;

void CmdBasicPrinter::print(ostream& out) const
{
    // determine longest command name
    unsigned maxlen = 0;
    for (auto it = mgr_->cmdBegin(); it != mgr_->cmdEnd(); ++it)
        if (it->first.size() > maxlen)
            maxlen = it->first.size();
    maxlen += 2;

    // print commands
    int count = 0;
    winsize ts;
    ioctl(fileno(stdout), TIOCGWINSZ, &ts);
    int nCmdPerLine = ts.ws_col / maxlen;
    for (auto it = mgr_->cmdBegin(); it != mgr_->cmdEnd(); ++it, ++count) {
        if (count > 1 && count % nCmdPerLine == 0)
            out << endl;
        out << left << setw(maxlen) << it->first;
    }
    out << endl;
}

