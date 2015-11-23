// **************************************************************************
// File       [ string_formatter.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/01/01 ]
// **************************************************************************

#include <iostream>

#include "string_formatter.h"

using namespace std;
using namespace CommonNs;

string StringFormatter::wrap(const string& input, const size_t& len) const {
    string output = input;

    // remove escape sequences
    EscSeqs escs = findEscSeqs(output);
    size_t nDelChar = 0;
    for (size_t i = 0; i < escs.size(); ++i) {
        pair<size_t, string>* esc = &escs[i];
        esc->first -= nDelChar;
        output.erase(esc->first, esc->second.size());
        nDelChar += esc->second.size();
    }

    // wrap string at target length
    size_t begin = 0;
    size_t end = begin + len;
    string sep = " -";
    vector<size_t> eols;
    while (end < output.size()) {
        // determine where each line ends
        if (output[end] != ' ')
            end--; // cannot delete the last character if it's not white
        if (sep.find_first_of(output[end]) == string::npos) {
            end = output.find_last_of(sep, end);
            if (end == string::npos)
                end = output.find_first_of(sep, begin + len);
        }

        // insert carriage return
        eols.push_back(end);

        // update position
        begin = end + 1;
        end = begin + len;
    }

    // put newlines in and escape sequences back
    size_t nIns = 0;
    size_t escNo = 0;
    size_t eolNo = 0;
    while (escNo < escs.size() || eolNo < eols.size()) {
        size_t escPos = output.size();
        size_t eolPos = output.size();
        if (escNo < escs.size())
            escPos = escs[escNo].first;
        if (eolNo < eols.size())
            eolPos = eols[eolNo];

        if (escPos < eolPos) {  // insert escape sequences
            output.insert(escPos + nIns, escs[escNo].second);
            nIns += escs[escNo].second.size();
            escNo++;
        }
        else { // insert EOLs
            if (output[eolPos + nIns] == ' ')
                output[eolPos + nIns] = '\n';
            else {
                output.insert(eolPos + nIns + 1, "\n");
                nIns++;
            }
            eolNo++;
        }
    }

    return move(output);
}

string StringFormatter::deleteWhite(const string& input) const {
    string output = input;
    string white = " \n\t";

    // remove leading whites
    size_t pos = output.find_first_not_of(white);
    output.erase(output.begin(), output.begin() + pos);

    // remove trailing whites
    pos = output.find_last_not_of(white);
    if (pos != string::npos)
        output.erase(output.begin() + pos + 1, output.end());


    // remove redundant whites in the middle of string
    bool found = false;
    for (size_t i = 0; i < output.size(); ++i) {
        char ch = output[i];
        if (white.find_first_of(ch) == string::npos)
            found = false;
        else {
            if (!found) {
                found = true;
                output[i] = ' ';
            }
            else {
                output.erase(i, 1);
                i--;
            }
        }
    }

    return move(output);
}

string StringFormatter::justify(const string& input , const size_t& len) const
{
    string output = input;

    size_t begin = 0;
    size_t end = output.find_first_of('\n');
    EscSeqs escs = findEscSeqs(output);
    size_t escNo = 0;
    size_t nDiff = 0;
    while (end < output.size()) {
        // find escape sequence length within the range
        size_t escLen = 0;
        for ( ; escNo < escs.size(); ++escNo) {
            if (escs[escNo].first + nDiff > end)
                break;
            escLen += escs[escNo].second.size();
        }

        // do not justify if string exceeds length
        if (end - begin >= len + escLen) {
            begin = end + 1;
            end = output.find_first_of('\n', begin);
            continue;
        }

        // count number of white spaces except leading ones
        int nWhts = 0;
        for (size_t i = output.find_first_not_of(' ', begin); i < end; ++i)
            if (output[i] == ' ')
                nWhts++;


        // insert white spaces from the rear
        int diff = (len + escLen) - (end - begin);
        int whtNo = 0;

        for (size_t i = begin; i < end; ++i) {
            if (whtNo > nWhts)
                break;
            size_t pos = end - i - 1 + begin;
            if (output[pos] != ' ')
                continue;
            int nIns = diff / nWhts + (whtNo < diff % nWhts ? 1 : 0);

            output.insert(output.begin() + pos, nIns, ' ');
            i += nIns;
            end += nIns;
            whtNo++;
        }

        // update position
        nDiff += diff;
        begin = end + 1;
        end = output.find_first_of('\n', begin);
    }

    return move(output);
}

StringFormatter::EscSeqs StringFormatter::findEscSeqs(
    const string& input) const
{
    vector<pair<size_t, string> > escs;

    bool escStart = false;
    for (size_t i = 0; i < input.size(); ++i) {
        if (input[i] == '\033') {
            escStart = true;
            escs.push_back(make_pair(i, ""));
        }
        if (!escStart)
            continue;
        bool end = input[i] >= '@' && input[i] <= '~' && input[i] != '[';
        if (end || i + 1 == input.size()) {
            escStart = false;
            pair<size_t, string>* esc = &escs[escs.size() - 1];
            size_t len = i - esc->first + 1;
            esc->second = input.substr(esc->first, len);
        }
    }

    return move(escs);
}

