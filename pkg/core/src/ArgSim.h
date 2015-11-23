#ifndef _SDD_ARGSIM_H_
#define _SDD_ARGSIM_H_
#include <string>
#include <fstream>
using namespace std;
class ArgSim{
public:
    ArgSim(){
        inVlogName      = "";
        inMdtName       = "";
        outLogName      = "";
        inPatName       = "";
        inSdfName       = "";
        outPatName      = "";
        tc              = 0.0;
        delta           = 0.6;
        UFS_thNum       = 32;
        APD_bkNum        = 32;   // #arrival time blocks
        APD_thNum        = 64;
        DSM_only        = false;
        dQ              = false;

    }
    ~ArgSim(){}
    string      inVlogName;
    string      inMdtName;
    string      outLogName;
    string      inPatName;
    string      inSdfName;
    string      outPatName;
    string      UDfName; // undetect fault file .udf
    float       delta;
    float       tc;
    int         UFS_thNum;
    int         APD_bkNum;   // #arrival time blocks
    int         APD_thNum;
    bool        DSM_only;   // only Cal DSM
    bool        dQ;
};
#endif
