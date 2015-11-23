// **************************************************************************
// File       [ string_formatter.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_STRING_FORMATTER_H__
#define __COMMON_STRING_FORMATTER_H__

#include <vector>
#include <string>

namespace CommonNs {

class StringFormatter {
public:
    StringFormatter() {}
    ~StringFormatter() {}

    std::string wrap(const std::string& input, const size_t& len) const;
    std::string deleteWhite(const std::string& input) const;
    std::string justify(const std::string& input, const size_t& len) const;

private:
    typedef std::vector<std::pair<size_t, std::string> > EscSeqs;
    EscSeqs findEscSeqs(const std::string & input) const;
};

};

#endif


