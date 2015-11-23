#ifndef _CUDA_DATA_H_
#define _CUDA_DATA_H_
#include <iostream>
#include <fstream>
#include <vector>
#include <stdlib.h>
#include <stdio.h>
#include <algorithm>
#include "interface/src/design.h"
#include "circuit.h"
#include "pattern.h"
#include "fault.h"
#include "logic.h"
#include "ArgSim.h"

#define  paraPatNum 64 
#if paraPatNum == 32
    #define PatValue int
#elif paraPatNum == 64
    #define PatValue size_t
#endif
using namespace std;
using namespace CoreNs;
using namespace IntfNs;
struct CircuitInfo {
    unsigned int DumgateNum;    // 0
    unsigned int fNum;          // 1
    unsigned int patNum;        // 2
    unsigned int piNum;         // 3
    unsigned int ppiNum;        // 4
    unsigned int poNum;         // 5
    unsigned int cirlvl;        // 6
    unsigned int gatesPerLvl;   // 7
    unsigned int MAX_INPUT_NUM; // 8
    unsigned int OrigateNum;    // 9
};

struct CudaFault {
    unsigned int   fType;  
    unsigned int   fLine;  
    unsigned int   fGate;  
};

class Pat {
public:
    Pat(unsigned int id_,unsigned int one_check_){
        id = id_;
        one_check = one_check_;
        old_one_check = 0;
        redundant = false;
    }
    ~Pat(){};
    bool         redundant;
    unsigned int one_check;   
    unsigned int old_one_check;
    unsigned int id;
};


class SddCudaSim{
public:
    SddCudaSim(Design* design_,Circuit* pCir_,PatternColl* pColl_,ArgSim *arg_){
        design = design_;
        pCir   = pCir_;
        pColl  = pColl_;
        arg    = arg_;
        cirInfo = (CircuitInfo*)malloc(sizeof(CircuitInfo));
        outSelPat.open(arg->outPatName.c_str());
        firstTrans = true;
        fout.open(arg->outLogName.c_str(),ios::out|ios::app);
    }
    ~SddCudaSim(){}
    void cudaDataTrans();
    void cudaSimulation();
    int  OriId2DumId(int gateId);
private:
    /*********************************
    **           Function           ** 
    **********************************/
    // Transfer function
    void transCirOri();
    void transCirDum();
    void transPat(PatternColl* newPatColl);
    void transFault();
    void transDelay();
    // Print Function
    void printCirOri();
    void printCirDum();
    void printPat();
    void printFault();
    void printDelay();
    
    void PrintBinaryValue(PatValue Val0,PatValue Val1);
    char getBitValue(PatValue &pv, const int& i); 
    char getBitValue(PatValue& l_,PatValue& h_, const int& bitIdx); 
    // Get Gate Name
    const char* getGateName(Gate* g);
    unsigned int getGateType(Gate* g);
    
    void boundAnalsys(int* Q, int* D, int LBfiler);
    void OneCheckCal(int* SFD,vector<Pat*>& patList,vector<unsigned int>& RmnfaultVec,vector<Pat*>& essPat,int patLoop);
    void SortNCompactPattern(vector<Pat*>& patList);
    void CompactRedundantFault(int* SFD,bool* fRdn_d,vector<unsigned int>& RmnfaultVec,unsigned int compLoop,unsigned int& DSMfNum);
    void SetRedundantPat(bool* pRdn_d,vector<Pat*>& patList,int patLoop);
    // Check function for GPU data
    void CheckDict(char* dictCPU,char* dict_d,vector<unsigned int>& RmnfaultVec,int patLoop,int patNum, CircuitInfo* cirInfo);
    void CheckLogicVal(PatValue* val_d,int patLoop,int patNum,CircuitInfo* cirInfo);
    void CheckDynamicAT(PatValue* val_d,float* at_d,int patLoop, CircuitInfo* cirInfo);
    void CheckFComp(int* SFD,char* dict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,vector<unsigned int>& RmnfaultVec,
                    int patLoop,int patNum, CircuitInfo* cirInfo, char mode); // Check fault Compaction
    void CheckRedundantPat(char* dict_d,int* SFD_d,vector<unsigned int>& RmnfaultVec,bool* pRdn_d,vector<Pat*>& patList,int patLoop,CircuitInfo* cirInfo);
    void DumpPattern(vector<Pat*>& patList);
    /*********************************
    **           Variable           ** 
    **********************************/
    // General pointer
    Circuit*                pCir;
    Design*                 design;
    PatternColl*            pColl;
    ArgSim*                 arg;
    CircuitInfo*            cirInfo;
    // Original Circuit Array
    unsigned int*           gFiOri;
    unsigned int*           gTypeOri;
    unsigned int*           foArrayOri;
    unsigned int*           foOffsetOri;
    unsigned int*           foIdxArrayOri;
    unsigned int*           gStrOnLvlOri;
    vector<unsigned int>    foVecOri;
    vector<unsigned int>    foIdxVecOri;
    // Dummy Circuit Array
    unsigned int*           gFiDum;       // gate Fi with dummy
    unsigned int*           gTypeDum;     // gate Type with dummy
    unsigned int*           gStrOnLvlDum; // first gateId of this level
    unsigned int*           gDum2Ori;     // get Ori Circuit gate Id from dum gate Id
    unsigned int*           foArrayDum;
    unsigned int*           foOffsetDum;
    unsigned int*           foIdxArrayDum;
    vector<unsigned int>    foVecDum;
    vector<unsigned int>    foIdxVecDum;
    vector<unsigned int>    dumCirId;   // transfer gateId in ori circuit to dummy circuit
    // Pattern Array
    PatValue*               pat_t0;
    PatValue*               pat_t1;
    bool                    firstTrans; // first time of trans pattern
    // Fault Array
    unsigned int*           fList;
    unsigned int*           fLvl;
    unsigned int*           fStrOnLvl;
    // Delay Array
    float*                  dList;
    // output File
    ofstream                outSelPat;
    ofstream                fout;
};

#endif
