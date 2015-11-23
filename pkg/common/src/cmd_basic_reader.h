// **************************************************************************
// File       [ cmd_basic_reader.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/06/27 created ]
// **************************************************************************

#ifndef __CMD_BASIC_READER_H__
#define __CMD_BASIC_READER_H__

#include <string>
#include <vector>

#include "cmd_reader.h"

namespace CommonNs {

class CmdBasicReader : public CmdReader {
public:
    CmdBasicReader(CmdMgr* mgr) : CmdReader(mgr)
        , input_{""}
        , bak_{""}
        , csrpos_{0}
        , maxpos_{0}
        , hisptr_{0} {};
    ~CmdBasicReader() {};

    std::string read() override;

protected:
    std::string input_;
    std::string bak_;
    std::string prompt_;
    size_t      csrpos_;  // cursor position
    size_t      maxpos_;  // max input position
    size_t      hisptr_;  // command history pointer

    // interface
    void setStdin() const;
    void resetStdin() const;
    int getWinCol() const;
    void refresh();
    void nonprintable(const char &ch);
    void showCddts(const std::vector<std::string>& cddts);
};


};

#endif


