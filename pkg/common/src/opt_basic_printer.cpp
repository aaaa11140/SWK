// **************************************************************************
// File       [ opt_man_printer.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#include <cstring>
#include <string>

#include "ansi.h"
#include "opt_mgr.h"
#include "opt_basic_printer.h"
#include "string_formatter.h"

using namespace std;
using namespace CommonNs;

void OptBasicPrinter::print(ostream& out) const
{
    nameUsage(out);
    synopsisUsage(out);
    descriptionUsage(out);
    argumentUsage(out);
    optionUsage(out);
}

void OptBasicPrinter::nameUsage(ostream& out) const { //{{{
    out << endl;
    out << ANSI_BOLD << "NAME" << ANSI_RESET;
    out << endl;
    string buf = mgr_->name + " - " + mgr_->brief;
    fitPrint(buf, winSize_ - tabSize_, true, out);
} //}}}
void OptBasicPrinter::synopsisUsage(ostream& out) const { //{{{
    out << endl;
    out << ANSI_BOLD << "SYNOPSIS" << ANSI_RESET;
    out << endl;

    string boolstr; // bool flags
    for (size_t i = 0; i < mgr_->nOpts(); ++i) {
        const Opt* opt = mgr_->getOpt(i);
        for (size_t j = 0; j < opt->nFlags(); ++j)
            if (opt->getFlag(j).size() == 1 && opt->type() == Opt::BOOL)
                boolstr += opt->getFlag(j);
    }
    if (boolstr.size() > 0) {
        boolstr = ANSI_BOLD + string("-") + boolstr + ANSI_RESET;
        boolstr = "[" + boolstr + "] ";
    }


    string longstr; // long flags
    for (size_t i = 0; i < mgr_->nOpts(); ++i) {
        const Opt* opt = mgr_->getOpt(i);
        for (size_t j = 0; j < opt->nFlags(); ++j) {
            string flag = opt->getFlag(j);
            if (flag.size() == 1 && opt->type() == Opt::BOOL)
                continue;
            // determine flag string
            string hyphenstr = flag.size() == 1 ? "-" : "--";
            string flagstr = ANSI_BOLD + hyphenstr + flag + ANSI_RESET;
            // determine meta string
            string metastr = ANSI_UNDER + opt->meta() + ANSI_RESET;
            if (opt->type() == Opt::STROPT)
                metastr = "[" + metastr + "]";
            // add long flags
            longstr += "[" + flagstr;
            if (opt->type() == Opt::STRREQ || opt->type() == Opt::STROPT)
                longstr += " " + metastr;
            longstr += "] ";
        }
    }


    string argstr; // arguments
    for (size_t i = 0; i < mgr_->nArgs(); ++i) {
        const Arg* arg = mgr_->getArg(i);
        string metastr = ANSI_UNDER + arg->meta() + ANSI_RESET;
        if (arg->type() == Arg::OPT || arg->type() == Arg::OPTINF)
            argstr += "[" + metastr + "]";
        else
            argstr += metastr;
        if (arg->type() == Arg::REQINF || arg->type() == Arg::OPTINF)
            argstr += "...";
        argstr += " ";
    }

    string namestr = ANSI_BOLD + mgr_->name + ANSI_RESET;
    string buf = namestr + " " + boolstr + longstr + argstr;
    fitPrint(buf, winSize_ - tabSize_, true, out);
} //}}}
void OptBasicPrinter::descriptionUsage(ostream& out) const { //{{{
    out << endl;
    out << ANSI_BOLD << "DESCRIPTION" << ANSI_RESET;
    out << endl;

    if (mgr_->des.size() == 0)
        fitPrint("NONE", winSize_ - tabSize_, true, out);
    else
        fitPrint(mgr_->des, winSize_ - tabSize_, true, out);
} //}}}
void OptBasicPrinter::argumentUsage(ostream& out) const { //{{{
    if (mgr_->nArgs() != 0) {
        out << endl;
        out << ANSI_BOLD << "ARGUMENT" << ANSI_RESET;
        out << endl;
    }

    string whts(tabSize_, ' ');
    for (size_t i = 0; i < mgr_->nArgs(); ++i) {
        const Arg* arg = mgr_->getArg(i);
        out << whts << ANSI_UNDER << arg->meta() << ANSI_RESET;
        bool nextline = arg->meta().size() + 2 >= tabSize_;
        if (nextline)
            out << endl;
        else
            for (size_t j = arg->meta().size(); j < tabSize_; ++j)
                out << ' ';
        fitPrint(arg->des(), winSize_ - 2 * tabSize_, nextline, out);
        out << endl;
    }
} //}}}
void OptBasicPrinter::optionUsage(ostream& out) const { //{{{
    if (mgr_->nOpts() > 0) {
        out << endl;
        out << ANSI_BOLD << "OPTION" << ANSI_RESET;
        out << endl;
    }

    for (size_t i = 0; i < mgr_->nOpts(); ++i) {
        const Opt* opt = mgr_->getOpt(i);

        // detemine flag string
        string flagstr;
        for (size_t j = 0; j < opt->nFlags(); ++j) {
            string flag = opt->getFlag(j);
            if (flag.size() == 1)
                flagstr += ANSI_BOLD + string("-") + flag + ANSI_RESET;
            else
                flagstr += ANSI_BOLD + string("--") + flag + ANSI_RESET;
            if (j + 1 != opt->nFlags())
                flagstr += ",";
        }
        string metastr = ANSI_UNDER + opt->meta() + ANSI_RESET;
        if (opt->type() == Opt::STRREQ)
            flagstr += " " + metastr;
        else if (opt->type() == Opt::STROPT)
            flagstr += " [" + metastr + "]";

        // print flag string
        string whts(tabSize_, ' ');
        out << whts << flagstr;

        // print description
        bool nextline = flagstr.size() + 2 >= tabSize_;
        if (nextline)
            out << endl;
        else
            for (size_t j = flagstr.size(); j < tabSize_; ++j)
                out << ' ';
        fitPrint(opt->des(), winSize_ - 2 * tabSize_, nextline, out);
        out << endl;
    }
} //}}}
void OptBasicPrinter::fitPrint(const string& input //{{{
    , const size_t& len
    , const bool& indent
    , ostream& out) const
{
    // remove redundant whites, wrap, and justify
    string output = input;
    StringFormatter strFmt;
    output = strFmt.deleteWhite(output);
    output = strFmt.wrap(output, len);
    output = strFmt.justify(output, len);

    // print
    string whts(winSize_ - len, ' ');
    size_t begin = 0;
    size_t pos = 0;
    do {
        pos = output.find_first_of('\n', begin);
        if (begin > 0 || indent)
            out << whts;
        out << output.substr(begin, pos - begin) << endl;
        begin = pos + 1;
    } while (pos != string::npos);
} //}}}

