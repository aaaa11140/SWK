// **************************************************************************
// File       [ cmd_basic_reader.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/07/16 created ]
// **************************************************************************

#include <iostream>
#include <iomanip>
#include <termios.h>    // setting stdin
#include <sys/ioctl.h>  // getting window size

#include "cmd_basic_reader.h"
#include "cmd_auto_completor.h"
#include "ascii.h"
#include "ansi.h"
#include "vt100.h"

using namespace std;
using namespace CommonNs;

string CmdBasicReader::read() { //{{{
    setStdin();

    // initialize VT100 and save cursor position
    printf("%s%s", VT100_ARM_ON, VT100_CSRS);
    fflush(stdout);

    // initialize input string related variables
    input_  = "";
    bak_    = "";
    prompt_ = "> ";
    csrpos_ = 0;
    maxpos_ = prompt_.size();
    hisptr_ = mgr_->nCmdHis();
    refresh();

    // perform actions on every keystroke
    char ch;
    while ((ch = getchar()) != ASCII_LF) {

        if (ch >= ASCII_MIN_PR && ch <= ASCII_MAX_PR) { // printable
            input_.insert(csrpos_, 1, ch);
            csrpos_++;
        }
        else
            nonprintable(ch);

        refresh();
    }
    printf("\n");

    resetStdin();

    return input_;
} //}}}
void CmdBasicReader::nonprintable(const char& ch) { //{{{
    string key(1, ch);

    // read escape sequence
    if (ch == ASCII_ESC) {
        char ch1;
        do {
            ch1 = getchar();
            key += ch1;
        } while (!isalpha(ch1) && ch1 != '~');
        // ends with alphabetic letter or '~'
    }

    // DEBUG
    //cout << "[key]" << endl;
    //for (size_t i = 0; i < key.size(); ++i)
        //cout << hex << int(key[i]) << " ";
    //cout << endl;


    // nonprintable actions
    CmdAutoCompletor autoCompletor;
    if (key[0] == ASCII_DEL || key[0] == ASCII_BS) {
        if (csrpos_ > 0) {
            input_.erase(csrpos_ - 1, 1);
            csrpos_--;
        }
    }
    else if (key[0] == ASCII_HT) {
        showCddts(autoCompletor.complete(mgr_, input_, csrpos_));
    }
    else if (key == ANSI_ARROW_UP) {
        if (hisptr_ == mgr_->nCmdHis())
            bak_ = input_;
        if (hisptr_ > 0) {
            hisptr_--;
            input_ = mgr_->cmdHis(hisptr_);
            csrpos_ = input_.size();
        }
    }
    else if (key == ANSI_ARROW_DOWN) {
        if (hisptr_ + 1 < mgr_->nCmdHis()) {
            hisptr_++;
            input_ = mgr_->cmdHis(hisptr_);
            csrpos_ = input_.size();
        }
        else if (hisptr_ + 1 == mgr_->nCmdHis()) {
            hisptr_ = mgr_->nCmdHis();
            input_ = bak_;
            csrpos_ = input_.size();
        }
    }
    else if (key == ANSI_ARROW_RIGHT) {
        if (csrpos_ < input_.size())
            csrpos_++;
    }
    else if (key == ANSI_ARROW_LEFT) {
        if (csrpos_ > 0)
            csrpos_--;
    }
    else if (key == ANSI_HOME) {
        csrpos_ = 0;
    }
    else if (key == ANSI_END) {
        csrpos_ = input_.size();
    }
} //}}}

void CmdBasicReader::setStdin() const { //{{{
    int fd = fileno(stdin);
    termios tcflags;
    tcgetattr(fd, &tcflags);
    tcflags.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(fd, TCSANOW, &tcflags);
} //}}}
void CmdBasicReader::resetStdin() const { //{{{
    int fd = fileno(stdin);
    termios tcflags;
    tcgetattr(fd, &tcflags);
    tcflags.c_lflag |= ICANON | ECHO;
    tcsetattr(fd, TCSANOW, &tcflags);
} //}}}
void CmdBasicReader::refresh() { //{{{
    // scroll screen on boundary
    if (prompt_.size() + input_.size() > maxpos_) {
        int nLinesPrev = maxpos_ / getWinCol();
        maxpos_ = prompt_.size() + input_.size();
        int nLinesCurr  = maxpos_ / getWinCol();
        for (int i = 0; i < nLinesCurr - nLinesPrev; ++i)
            printf("%s", VT100_SCRU);
    }

    // clear current text
    int nRows = maxpos_ / getWinCol();
    printf("%s", VT100_CSRR);
    for (int i = 0; i < nRows; ++i)
        printf("%s", VT100_CSRU);
    printf("%s", VT100_ERSD);
    fflush(stdout);

    // reprint prompt and cmd string
    printf("%s%s", prompt_.c_str(), input_.c_str());

    // move cursor back to cursor position
    int csrpos = prompt_.size() + csrpos_;
    int row = nRows - csrpos / getWinCol();
    int col = csrpos % getWinCol();
    printf("%s", VT100_CSRR);
    for (int i = 0; i < row; ++i)
        printf("%s", VT100_CSRU);
    for (int i = 0; i < col; ++i)
        printf("%s", VT100_CSRF);

    fflush(stdout);
} //}}}
int CmdBasicReader::getWinCol() const { //{{{
    winsize ts;
    ioctl(fileno(stdout), TIOCGWINSZ, &ts);
    return ts.ws_col;
} //}}}
void CmdBasicReader::showCddts(const vector<string>& cddts) { //{{{
    // only show when number of candidates >= 2
    if (cddts.size() < 2)
        return;

    size_t maxlen = 0;
    for (size_t i = 0; i < cddts.size(); ++i)
        if (cddts[i].size() > maxlen)
            maxlen = cddts[i].size();

    printf("%s%s", VT100_CSRR, VT100_SCRU);
    fflush(stdout);
    size_t nFilesPerLine = (size_t)getWinCol() / (maxlen + 2);
    for (size_t i = 0; i < cddts.size(); ++i) {
        printf("%s", cddts[i].c_str());
        for (size_t j = cddts[i].size(); j < maxlen + 2; ++j)
            printf(" ");
        if ((i + 1) % nFilesPerLine == 0)
            printf("\n");
    }
    if (cddts.size() % nFilesPerLine != 0)
        printf("\n");
    size_t nLinesPrev = maxpos_ / (size_t)getWinCol();
    size_t nLinesCurr = (prompt_.size() + input_.size()) / (size_t)getWinCol();
    for (size_t i = 0; i < nLinesPrev - (nLinesCurr - nLinesPrev); ++i) {
        printf("%s", VT100_SCRU);
        fflush(stdout);
    }
    printf("%s", VT100_CSRS);
    fflush(stdout);
} //}}}


