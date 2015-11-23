#include "SddCudaSim.h"
#include "ArgSim.h"
#include <iostream>
#include <fstream>
#include <cuda.h>
#include <cutil_inline.h>
#include <iomanip>
#include <stdlib.h>
#include <stdio.h>
#define  SBA_thNum      512 // SBA = Static Bound Analysis
#define  SBA_bkNum      2
#define  LS_thNum       512 // Logic simulation
#define  LS_bkNum       1
#define  DBA_thNum      256 // DBA = Dynamic Bound Analysis
#define  DBA_bkNum      128
#define  EVB_thNum      128 // EVB = Evaluation Bound
#define  EVB_bkNum     256
#define  UFS_bkNum      64 // useless
#define  TFS_thGroup    1
#define  FC_thNum       1024    // number of threads to Compact faults in a block
#define  SFD_thNum      256 // SFD build thread Number
#define  SFD_bkNum      256

//#define delta 0.6
using namespace std;
using namespace IntfNs;

char getBitValue(PatValue& l_,PatValue& h_, const int& bitIdx);
// print function
void PrintBinaryValue(PatValue Val0,PatValue Val1);
void PrintDict(char* partialDict_d,int i, CircuitInfo* cirInfo);
void PrintSFD(char* partialDict_d,int* SFD,int* SFD_d,vector<unsigned int>& RmnfaultList,int patLoop,int patNum, CircuitInfo* cirInfo);

texture<unsigned int, 1, cudaReadModeElementType> gDum2Ori_t;
texture<unsigned int, 1, cudaReadModeElementType> cirInfo_t;
__global__ void staticBoundAnalysis(unsigned int* gTypeOri_d,float* dList_d,unsigned int* foArrayOri_d,unsigned int* foIdxArrayOri_d,unsigned int* foOffsetOri_d,float* PT_UBLB_d,float* Ttc_d,
                          unsigned int* gFiOri_d,unsigned int* gStrOnLvlOri_d,float* ATUB_d);
__global__ void logicSim(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,unsigned int* gStrOnLvlOri_d,PatValue* pat_t0_d,PatValue* pat_t1_d,PatValue* pat_t0_z,PatValue* pat_t1_z,
                          PatValue* val_d,unsigned int* Rmnfault_d,unsigned int* Rmnfault_z,unsigned int* RmnfNum_d,unsigned int RmnfNum,unsigned int RmnpNum,int patLoop);
__global__ void dynamicBoundAnalysis(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,float* at_d,unsigned int* gStrOnLvlOri_d,PatValue* val_d,float* dList_d,int currLvl);

__global__ void evalLBCriteria(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,float* at_d,float* ATUB_d,float* PT_UBLB_d,float* Ttc_d,float* dList_d,unsigned int* gStrOnLvlOri_d,
                               PatValue* val_d,unsigned int* fList_d,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,bool* fRdn_d,unsigned int iterNum,float delta);
__global__ void fCompact1(unsigned int* fMask_d,unsigned int* fSum_d, unsigned int* bSum_d,unsigned int* RmnfNum_d);
__global__ void fCompact2(unsigned int* fSum_d, unsigned int* bSum_d,unsigned int FC_bkNum);
__global__ void uniformAdd(unsigned int* fMask_d,unsigned int* fSum_d, unsigned int* bSum_d,
                           unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,unsigned int* LBRmnfault_d,unsigned int* LBRmnfNum_d,bool afterLB);
__global__ void untimedFaultSim(unsigned int* gTypeDum_d,unsigned int* gFiDum_d,unsigned int* foArrayDum_d,unsigned int* foIdxArrayDum_d,unsigned int* foOffsetDum_d,
                                unsigned int* gStrOnLvlDum_d,PatValue* val_d,unsigned int* fList_d,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,
                                PatValue* twoLvlval_d,unsigned int* twoLvlfG_d,unsigned int* EventList_d,unsigned int* fLvl_d);
__global__ void evalUBCriteria(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,float* at_d,float* ATUB_d,float* PT_UBLB_d,float* Ttc_d,float* dList_d,
                               unsigned int* gStrOnLvlOri_d,unsigned int* fList_d,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,float delta);
__global__ void actualPathDelayCal(unsigned int* gTypeDum_d,unsigned int* gFiDum_d,unsigned int* foArrayDum_d,unsigned int* foIdxArrayDum_d,unsigned int* foOffsetDum_d,
                                   float* at_d,float* Ttc_d,float* dList_d,unsigned int* gStrOnLvlDum_d,PatValue* val_d,unsigned int* fList_d,unsigned int* Rmnfault_d,
                                   unsigned int* RmnfNum_d,char* partialDict_d,PatValue* twoLvlval_d,float* twoLvlat_d,unsigned int* twoLvlfG_d,unsigned int* EventList_d,
                                   unsigned int* fLvl_d,float* ATUB_d,float* PT_UBLB_d,float delta);

__global__ void SFDRdnPatBuild(char* partialDict_d,int* SFD_d,int* SFD_z,unsigned int* LBRmnfault_d,unsigned int* LBRmnfNum_d,
                                    bool* pRdn_d,unsigned int RmnpNum,unsigned int* fMask_d,int patLoop,int mode);
__global__ void SFDAnalysis(char* partialDict_d,int* SFD_d,int* SFD_z,unsigned int* fMask_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,
                            bool* pRdn_d,unsigned int RmnpNum,int patLoop,int iterNum,int mode);
__device__ bool isInv(unsigned int gType);
__device__ void evalGate(unsigned int gateId,unsigned int gType,unsigned int gFiOri0,unsigned int gFiOri1,unsigned int gFiOri2,unsigned int gFiOri3,
                         PatValue* val_d,PatValue hold_capture,int timeframe);
__device__ void evalGate(unsigned int gType,PatValue fi0l_,PatValue fi0h_,PatValue fi1l_,PatValue fi1h_,PatValue fi2l_,PatValue fi2h_,PatValue fi3l_,PatValue fi3h_,PatValue* twoLvlval_d);
__device__ char getTrans(PatValue t0_l_,PatValue t0_h_,PatValue t1_l_,PatValue t1_h_,int bitIdx); // 0 = Rising ; 1 = Falling ; 2 = static
__device__ char getFiNum(unsigned int gType);
__device__ char transType(unsigned int gType, char trans);
__device__ bool getCtrl(unsigned int gType, char trans);
__device__ char getBV(PatValue pv,int bitIdx);
__device__ char getV(PatValue fl_,PatValue fh_,PatValue gl_, PatValue gh_,unsigned int bitIdx);
//{{{ void cudaSimulation()
void SddCudaSim::cudaSimulation(){

    cout << " ==========================================================" << endl;
    cout << " =                  Start Cuda Sim                        =" << endl;
    cout << " ==========================================================" << endl;
    fout << " ==========================================================" << endl;
    fout << " =                  Start Cuda Sim                        =" << endl;
    fout << " ==========================================================" << endl;
    unsigned int timer = 0;
    (cutCreateTimer(&timer));
    (cutStartTimer(timer));
    int idev = 0;
    cudaSetDevice(idev);
    cudaDeviceReset();
    // Memory setup
    // _d means pointer on device
    // _s means pointer on device share memory
    CircuitInfo*    cirInfo_d;
    unsigned int*   gDum2Ori_d;
    // Ori Circuit
    unsigned int*   gTypeOri_d;
    unsigned int*   gFiOri_d;
    unsigned int*   gStrOnLvlOri_d;
    // Dum Circuit
    unsigned int*   gTypeDum_d;
    unsigned int*   gFiDum_d;
    unsigned int*   gStrOnLvlDum_d;
    // Fanout
    unsigned int*   foArrayOri_d;
    unsigned int*   foIdxArrayOri_d;
    unsigned int*   foOffsetOri_d;

    unsigned int*   foArrayDum_d;
    unsigned int*   foIdxArrayDum_d;
    unsigned int*   foOffsetDum_d;
    // delay and path delay
    float*          dList_d;
    float*          PT_UBLB_d;
    float*          ATUB_d;
    float*          Ttc_d;
    float*          at_d;
    // value
    PatValue*       val_d;
    // dictionary
    char*           partialDict_d;
    // fault
    unsigned int*   fList_d;
    // Redundant fault is fault that not detect by anything (U faults without any pattern ID)
    // This kind of faults won't be calculated after second iteration
    // In second iteration Redudant Fault are faults don't use bond Analysis
    bool*           fRdn_d;  // to see if fault is redundant
    // for pdSim
    unsigned int*   fLvl_d;
    PatValue*       twoLvlval_d;
    float*          twoLvlat_d;
    unsigned int*   twoLvlfG_d;
    unsigned int*   EventList_d;
    unsigned int*   RmnfNum_d;
    unsigned int*   LBRmnfNum_d;
    // for fault compaction
    int             FC_bkNum = (cirInfo->fNum - 1)/FC_thNum + 1;
    unsigned int*   fSum_d;     // fault number accumulate
    unsigned int*   fMask_d;     // fault should remained
    unsigned int*   bSum_d;
    //{{{ cudaMalloc & cpy
    cudaMalloc((void**)&cirInfo_d   ,sizeof(CircuitInfo));
    cudaMalloc((void**)&gDum2Ori_d  ,sizeof(unsigned int)*(cirInfo->DumgateNum));
    // Ori Circuit
    cudaMalloc((void**)&gTypeOri_d     ,sizeof(unsigned int)*(cirInfo->OrigateNum));
    cudaMalloc((void**)&gFiOri_d       ,sizeof(unsigned int)*(cirInfo->OrigateNum)*4);
    cudaMalloc((void**)&gStrOnLvlOri_d  ,sizeof(unsigned int)*(cirInfo->cirlvl + 1));
    // Dum Circuit
    cudaMalloc((void**)&gTypeDum_d     ,sizeof(unsigned int)*(cirInfo->DumgateNum));
    cudaMalloc((void**)&gFiDum_d       ,sizeof(unsigned int)*(cirInfo->DumgateNum)*4);
    cudaMalloc((void**)&gStrOnLvlDum_d ,sizeof(unsigned int)*(cirInfo->cirlvl + 1));
    // fanout
    cudaMalloc((void**)&foArrayOri_d      ,sizeof(unsigned int)*(foOffsetOri[cirInfo->OrigateNum]));
    cudaMalloc((void**)&foIdxArrayOri_d   ,sizeof(unsigned int)*(foOffsetOri[cirInfo->OrigateNum]));
    cudaMalloc((void**)&foOffsetOri_d     ,sizeof(unsigned int)*(cirInfo->OrigateNum + 1));

    cudaMalloc((void**)&foArrayDum_d      ,sizeof(unsigned int)*(foOffsetDum[cirInfo->DumgateNum]));
    cudaMalloc((void**)&foIdxArrayDum_d   ,sizeof(unsigned int)*(foOffsetDum[cirInfo->DumgateNum]));
    cudaMalloc((void**)&foOffsetDum_d     ,sizeof(unsigned int)*(cirInfo->DumgateNum + 1));
    // delay and path calculation
    cudaMalloc((void**)&dList_d      ,sizeof(float)*(cirInfo->OrigateNum)*8);
    cudaMalloc((void**)&PT_UBLB_d    ,sizeof(float)*(cirInfo->OrigateNum)*4);
    cudaMalloc((void**)&Ttc_d        ,sizeof(float));
    cudaMalloc((void**)&ATUB_d      ,sizeof(float)*(cirInfo->OrigateNum)*2);
    cudaMalloc((void**)&at_d         ,sizeof(float)*(cirInfo->OrigateNum)*paraPatNum);
    // fault
    cudaMalloc((void**)&fList_d      ,sizeof(float)*(cirInfo->fNum)*3);
    cudaMalloc((void**)&fRdn_d       ,sizeof(bool)*(cirInfo->fNum));
    // dictionary
    cudaMalloc((void**)&partialDict_d      ,sizeof(char)*(cirInfo->fNum)*paraPatNum);
    // value
    cudaMalloc((void**)&val_d       ,sizeof(PatValue)*(cirInfo->OrigateNum)*4*LS_bkNum);
    // for pdSim
    cudaMalloc((void**)&fLvl_d       ,sizeof(unsigned int)*(cirInfo->fNum));

    cudaMalloc((void**)&twoLvlval_d  ,sizeof(unsigned int)*2*(cirInfo->gatesPerLvl)*(paraPatNum+1)*arg->APD_bkNum*2*2*TFS_thGroup);       // two for val l_/h_ and two for pre/curr val
    cudaMalloc((void**)&twoLvlfG_d   ,sizeof(unsigned int)*(cirInfo->gatesPerLvl)*arg->APD_bkNum*(1+paraPatNum)*TFS_thGroup);       // two for event List
    cudaMalloc((void**)&EventList_d  ,sizeof(unsigned int)*(cirInfo->gatesPerLvl)*arg->APD_bkNum*(1+paraPatNum)*2*TFS_thGroup);     // two for event List
    cudaMalloc((void**)&RmnfNum_d    ,sizeof(unsigned int)*2);
    cudaMalloc((void**)&LBRmnfNum_d  ,sizeof(unsigned int));
    // fault Compaction
    cudaMalloc((void**)&fSum_d       ,sizeof(unsigned int)*(cirInfo->fNum));
    cudaMalloc((void**)&fMask_d       ,sizeof(unsigned int)*(cirInfo->fNum));
    cudaMalloc((void**)&bSum_d        ,sizeof(unsigned int)*FC_bkNum);
    cout <<" [Correct]: Finish Malloc...\n";
    // Memcpy
    cudaMemcpy(cirInfo_d       ,cirInfo     ,sizeof(CircuitInfo)        ,cudaMemcpyHostToDevice);
    cudaMemcpy(gDum2Ori_d      ,gDum2Ori     ,sizeof(unsigned int)*(cirInfo->DumgateNum)                        ,cudaMemcpyHostToDevice);
    // Ori Circuit
    cudaMemcpy(gTypeOri_d      ,gTypeOri       ,sizeof(unsigned int)*(cirInfo->OrigateNum)    ,cudaMemcpyHostToDevice);
    cudaMemcpy(gFiOri_d        ,gFiOri         ,sizeof(unsigned int)*(cirInfo->OrigateNum)*4  ,cudaMemcpyHostToDevice);
    cudaMemcpy(gStrOnLvlOri_d  ,gStrOnLvlOri ,sizeof(unsigned int)*(cirInfo->cirlvl + 1)                        ,cudaMemcpyHostToDevice);
    // Dum Circuit
    cudaMemcpy(gTypeDum_d      ,gTypeDum       ,sizeof(unsigned int)*(cirInfo->DumgateNum)    ,cudaMemcpyHostToDevice);
    cudaMemcpy(gFiDum_d        ,gFiDum         ,sizeof(unsigned int)*(cirInfo->DumgateNum)*4  ,cudaMemcpyHostToDevice);
    cudaMemcpy(gStrOnLvlDum_d  ,gStrOnLvlDum   ,sizeof(unsigned int)*(cirInfo->cirlvl + 1)                        ,cudaMemcpyHostToDevice);
    // fanout
    cudaMemcpy(foArrayOri_d       ,foArrayOri      ,sizeof(unsigned int)*(foOffsetOri[cirInfo->OrigateNum])          ,cudaMemcpyHostToDevice);
    cudaMemcpy(foIdxArrayOri_d    ,foIdxArrayOri   ,sizeof(unsigned int)*(foOffsetOri[cirInfo->OrigateNum])          ,cudaMemcpyHostToDevice);
    cudaMemcpy(foOffsetOri_d      ,foOffsetOri     ,sizeof(unsigned int)*(cirInfo->OrigateNum+1)                        ,cudaMemcpyHostToDevice);

    cudaMemcpy(foArrayDum_d       ,foArrayDum      ,sizeof(unsigned int)*(foOffsetDum[cirInfo->DumgateNum])          ,cudaMemcpyHostToDevice);
    cudaMemcpy(foIdxArrayDum_d    ,foIdxArrayDum   ,sizeof(unsigned int)*(foOffsetDum[cirInfo->DumgateNum])          ,cudaMemcpyHostToDevice);
    cudaMemcpy(foOffsetDum_d      ,foOffsetDum     ,sizeof(unsigned int)*(cirInfo->DumgateNum+1)                        ,cudaMemcpyHostToDevice);
    // delay
    cudaMemcpy(dList_d         ,dList       ,sizeof(float)*(cirInfo->OrigateNum)*8         ,cudaMemcpyHostToDevice);
    // fault
    cudaMemcpy(fList_d         ,fList       ,sizeof(unsigned int)*(cirInfo->fNum)*3     ,cudaMemcpyHostToDevice);
    // pdSim
    cudaMemcpy(fLvl_d          ,fLvl         ,sizeof(unsigned int)*(cirInfo->fNum)                              ,cudaMemcpyHostToDevice);
    cout <<" [Correct]: Finish Memcpy...\n";
    //}}}
    //******* Prepare for zero copy ******
    cudaSetDeviceFlags(cudaDeviceMapHost);
    // pattern
    int patDataSizeGPU = sizeof(PatValue)*(cirInfo->piNum+cirInfo->ppiNum)*2*LS_bkNum*2;
    int patDataSizeCPU = sizeof(PatValue)*(cirInfo->piNum+cirInfo->ppiNum)*2*((cirInfo->patNum -1)/paraPatNum + 1);
    // _z is temp for zero copy
    // _c is temp on CPU memory
    PatValue*       pat_t0_d;
    PatValue*       pat_t1_d;
    PatValue*       pat_t0_z;   // zero copy memory place
    PatValue*       pat_t1_z;
    PatValue*       pat_t0_c = (PatValue*)malloc(patDataSizeCPU); // memory on CPU for zero copy
    PatValue*       pat_t1_c = (PatValue*)malloc(patDataSizeCPU);
    // pattern redundant
    bool*           pRdn_d;  // to see if pattern is redundant

    cudaMalloc((void**)&pat_t0_d    ,patDataSizeGPU);
    cudaMalloc((void**)&pat_t1_d    ,patDataSizeGPU);
    cudaMalloc((void**)&pRdn_d      ,sizeof(bool)*paraPatNum);
    cudaHostAlloc(&pat_t0_c,patDataSizeCPU,cudaHostAllocMapped);
    cudaHostAlloc(&pat_t1_c,patDataSizeCPU,cudaHostAllocMapped);
    cudaHostGetDevicePointer(&pat_t0_z,pat_t0_c,idev);
    cudaHostGetDevicePointer(&pat_t1_z,pat_t1_c,idev);
    cout <<" [Correct]: Finish Zero Copy...\n";
    // Remain fault array after fault drop
    unsigned int*   Rmnfault = (unsigned int*)malloc(sizeof(unsigned int)*cirInfo->fNum);
    unsigned int*   Rmnfault_d;
    unsigned int*   Rmnfault_z;
    cout<<" > Finish Rmnfault alloc\n";

    cudaMalloc((void**)&Rmnfault_d   ,sizeof(unsigned int)*(cirInfo->fNum));
    cudaHostAlloc(&Rmnfault,sizeof(int)*cirInfo->fNum,cudaHostAllocMapped);
    cudaHostGetDevicePointer(&Rmnfault_z,Rmnfault,idev);
    // LB Remain fault Array
    // This array record faults that is remained after DSMLB criteria
    // Check partial dictionary of these faults to get SFD
    unsigned int* LBRmnfault_d;
    cudaMalloc((void**)&LBRmnfault_d   ,sizeof(unsigned int)*(cirInfo->fNum));
    // simple fault dictionary
    //**************************************
    int*            SFD = (int*)malloc(sizeof(int)*(cirInfo->fNum));        // simple fault dictionary
    int*            SFD_d;
    int*            SFD_z;
    cudaMalloc((void**)&SFD_d,sizeof(int)*cirInfo->fNum);
    cudaHostAlloc(&SFD,sizeof(int)*cirInfo->fNum,cudaHostAllocMapped);
    cudaHostGetDevicePointer(&SFD_z,SFD,idev);
    cout<<" > Finish SFD alloc\n";
    //************************************
    //******** Texture Momory *************
    cudaBindTexture(0,gDum2Ori_t,gDum2Ori_d);
    cudaBindTexture(0,cirInfo_t,cirInfo_d);
    //*************************************
    // ******* Report Memory Usage ********
    size_t free_byte;
    size_t total_byte;
    if(cudaMemGetInfo(&free_byte,&total_byte) != cudaSuccess){
        printf(" [Error]: Memory Get Info Fail!!\n");
        fout.close();
        return;
    }
    cout<<" ------------------------------------------\n";
    cout<<" | GPU memory free = "<<setw(12)<<(float)(free_byte)/1024.0/1024.0<<" MB      |\n";
    cout<<" | GPU memory used = "<<setw(12)<<(float)(total_byte - free_byte)/1024.0/1024.0<<" MB      |\n";
    cout<<" ------------------------------------------\n";
    fout<<" ------------------------------------------\n";
    fout<<" | GPU memory free = "<<setw(12)<<(float)(free_byte)/1024.0/1024.0<<" MB      |\n";
    fout<<" | GPU memory used = "<<setw(12)<<(float)(total_byte - free_byte)/1024.0/1024.0<<" MB      |\n";
    fout<<" ------------------------------------------\n";

    cout<<" | Mem Setup Time  = "<<setw(12)<< cutGetTimerValue(timer) <<" ms      |\n";
    cout<<" ------------------------------------------\n";

    fout<<" | Mem Setup Time  = "<<setw(12)<< cutGetTimerValue(timer) <<" ms      |\n";
    fout<<" ------------------------------------------\n";


    //********** Static Bound Analysis *************
    staticBoundAnalysis<<<SBA_bkNum,SBA_thNum,sizeof(float)*SBA_thNum>>>(
                          gTypeOri_d,dList_d,foArrayOri_d,foIdxArrayOri_d,foOffsetOri_d,
                          PT_UBLB_d,Ttc_d,gFiOri_d,gStrOnLvlOri_d,ATUB_d);
    cudaThreadSynchronize();
    cudaFree(foArrayOri_d);
    cudaFree(foIdxArrayOri_d);
    cudaFree(foOffsetOri_d);
    // *********** Output Longest path *************
    float* Ttc = new float;
    cudaMemcpy(Ttc        ,Ttc_d       ,sizeof(float)   ,cudaMemcpyDeviceToHost);
    cout<<" | Longest Path    = "<<setw(12)<< Ttc[0] <<" ns      |\n";
    cout<<" | GatesPerLvl     = "<<setw(12)<< cirInfo->gatesPerLvl <<"         |\n";
    cout<<" ------------------------------------------\n";
    fout<<" | Longest Path    = "<<setw(12)<< Ttc[0] <<" ns      |\n";
    fout<<" | GatesPerLvl     = "<<setw(12)<< cirInfo->gatesPerLvl <<"         |\n";
    fout<<" ------------------------------------------\n";
    bool finishComp = false;    // to see if FaultSimulation step is done
    // Initialize pattern list
    // patList is used to save pat Id, on_check and if it is redundant
    vector<Pat*> patList;
    for(unsigned int i = 0 ; i < cirInfo->patNum; ++i){
        Pat* pat = new Pat(i,0);
        patList.push_back(pat);
    }
    int iterNum = 0;
    // Initialize Reain fault List & simple fault dictionary
    vector<unsigned int>    RmnfaultList;
    vector<unsigned int>    faultList;
    vector<Pat*>             essPat; // pattern for essential faults
    // Initialize fault List
    for(unsigned int i = 0 ; i < cirInfo->fNum; ++i){
        faultList.push_back(i);
        essPat.push_back(0);
    }
    // Pattern Selection algorithm
    unsigned int oldPatNum = patList.size();
    unsigned int DSMfNum = 0;
    while(!finishComp){
        // Start a new iteration
        cout<<" ==========================================================\n";
        cout<<" |              Compact Iteration "<<setw(3)<<iterNum<<"                     |\n";
        cout<<" ----------------------------------------------------------\n";
        fout<<" ==========================================================\n";
        fout<<" |              Compact Iteration "<<setw(3)<<iterNum<<"                     |\n";
        fout<<" ----------------------------------------------------------\n";
        int patDataSize = sizeof(PatValue)*(cirInfo->piNum+cirInfo->ppiNum)*2*((patList.size()-1)/paraPatNum + 1);
        // copy first pattern
        cudaMemcpy(pat_t0_d         ,pat_t0       ,sizeof(PatValue)*(cirInfo->piNum+cirInfo->ppiNum)*2         ,cudaMemcpyHostToDevice);
        cudaMemcpy(pat_t1_d         ,pat_t1       ,sizeof(PatValue)*(cirInfo->piNum+cirInfo->ppiNum)*2         ,cudaMemcpyHostToDevice);
        // zero copy pattern
        memcpy(pat_t0_c,pat_t0,patDataSize);
        memcpy(pat_t1_c,pat_t1,patDataSize);
        // copy remain fault List
        RmnfaultList.clear();
        RmnfaultList = faultList;

        // Reset SFD every iteration
        for(unsigned int i = 0 ; i < faultList.size(); ++i){
            SFD[faultList[i]] = -4;
            essPat[faultList[i]] = 0;
        }
        // Reset patList one_check
        for(unsigned int i = 0 ; i < patList.size(); ++i)
            patList[i]->one_check = 0;
        cout<<" | Pattern Size :"<<patList.size() <<" <--- OldPattern Size: "<<oldPatNum<<endl;
        fout<<" | Pattern Size :"<<patList.size() <<" <--- OldPattern Size: "<<oldPatNum<<endl;
        cout<<" ----------------------------------------------------------\n";
        fout<<" ----------------------------------------------------------\n";
        cout<<" | Pat. Loop |         Remain Fault Size                  |\n";
        fout<<" | Pat. Loop |         Remain Fault Size                  |\n";
        cout<<" ----------------------------------------------------------\n";
        fout<<" ----------------------------------------------------------\n";

        oldPatNum = patList.size();
        // get m pattern in every pattern Loop
        for(int patLoop = 0; patLoop < (patList.size()-1)/paraPatNum + 1; patLoop+=LS_bkNum){
            // Set zero copy Remain fault
            memcpy(Rmnfault,&RmnfaultList[0],sizeof(unsigned int)*RmnfaultList.size());
            FC_bkNum = (RmnfaultList.size() - 1)/(FC_thNum*2) + 1; // Fault Compaction block Number
            cout<<" |"<<setw(10)<<patLoop<< " | ";
            cout<<setw(30)<<RmnfaultList.size()<<"             |"<<endl;
            fout<<" |"<<setw(10)<<patLoop<< " | ";
            fout<<setw(30)<<RmnfaultList.size()<<"             |"<<endl;
            if(RmnfaultList.size() == 0){ // all the faults have been detected twice
                break;
            }
            // Logic Simulation
            logicSim<<<LS_bkNum,LS_thNum>>>(gTypeOri_d,gFiOri_d,gStrOnLvlOri_d,pat_t0_d,pat_t1_d,pat_t0_z,pat_t1_z,val_d,
                                            Rmnfault_d,Rmnfault_z,RmnfNum_d,RmnfaultList.size(),patList.size(),patLoop);
            // Output logic simulation result
            //CheckLogicVal(val_d,patLoop,patList.size(),cirInfo);

            // Dynamic Bound Analysis
            for(int lvl = 0 ; lvl < cirInfo->cirlvl;++lvl){
                // perform level by level
                dynamicBoundAnalysis<<<DBA_bkNum,DBA_thNum>>>(gTypeOri_d,gFiOri_d,at_d,gStrOnLvlOri_d,val_d,dList_d,lvl);
                cudaThreadSynchronize();
            }
            //  Check dynamic Cal Result
            //CheckDynamicAT(val_d,at_d,patLoop,cirInfo);

            // evaluate DSMLB criteria (Use PDUB)
            evalLBCriteria<<<EVB_bkNum,EVB_thNum>>>(gTypeOri_d,gFiOri_d,at_d,ATUB_d,PT_UBLB_d,Ttc_d,dList_d,
                                                     gStrOnLvlOri_d,val_d,fList_d,partialDict_d,Rmnfault_d,RmnfNum_d,fRdn_d,iterNum,arg->delta);
            // SFDAnalysis prepare for fault drop and Initialize SFD and redundant pattern
            SFDAnalysis<<<SFD_bkNum,SFD_thNum>>>(partialDict_d,SFD_d,SFD_z,fMask_d,Rmnfault_d,RmnfNum_d,pRdn_d,patList.size(),patLoop,iterNum,0);
            // Perform fault dropping, left fault needs untimed fault Sim
            fCompact1<<<FC_bkNum,FC_thNum>>>(fMask_d,fSum_d,bSum_d,RmnfNum_d);
            fCompact2<<<1,FC_thNum>>>(fSum_d,bSum_d,FC_bkNum);
            uniformAdd<<<FC_bkNum,FC_thNum>>>(fMask_d,fSum_d,bSum_d,Rmnfault_d,RmnfNum_d,LBRmnfault_d,LBRmnfNum_d,true);

            // Dynamic Share Memory malloc
            unsigned int sharedSize = sizeof(PatValue)*(arg->UFS_thNum*9) +
                                      sizeof(unsigned int)*(2+arg->UFS_thNum*2);
            untimedFaultSim<<<arg->APD_bkNum*(paraPatNum+1),arg->UFS_thNum,sharedSize>>>(gTypeDum_d,gFiDum_d,foArrayDum_d,foIdxArrayDum_d,foOffsetDum_d,
                                                                   gStrOnLvlDum_d,val_d,fList_d,partialDict_d,Rmnfault_d,RmnfNum_d,
                                                                   twoLvlval_d,twoLvlfG_d,EventList_d,fLvl_d);
            cudaThreadSynchronize();
            // evaluate DSMUB criteria (Use PDLB)
            evalUBCriteria<<<EVB_bkNum,EVB_thNum>>>(gTypeOri_d,gFiOri_d,at_d,ATUB_d,PT_UBLB_d,Ttc_d,dList_d,
                                                    gStrOnLvlOri_d,fList_d,partialDict_d,Rmnfault_d,RmnfNum_d,arg->delta);
            cudaThreadSynchronize();

            SFDAnalysis<<<SFD_bkNum,SFD_thNum>>>(partialDict_d,SFD_d,SFD_z,fMask_d,Rmnfault_d,RmnfNum_d,pRdn_d,patList.size(),patLoop,iterNum,1);
            if(iterNum > 0){
                SFDRdnPatBuild<<<SFD_bkNum,SFD_thNum>>>(partialDict_d,SFD_d,SFD_z,Rmnfault_d,RmnfNum_d,pRdn_d,patList.size(),fMask_d,patLoop,1);
            }
            // Fault dropping again, left fault that needs actual path delay
            fCompact1<<<FC_bkNum,FC_thNum>>>(fMask_d,fSum_d,bSum_d,RmnfNum_d);
            fCompact2<<<1,FC_thNum>>>(fSum_d,bSum_d,FC_bkNum);
            uniformAdd<<<FC_bkNum,FC_thNum>>>(fMask_d,fSum_d,bSum_d,Rmnfault_d,RmnfNum_d,LBRmnfault_d,LBRmnfNum_d,false);
            cudaThreadSynchronize();
            // ********* Check SFD & Stream Compaction *************
            //PrintSFD(partialDict_d,SFD,SFD_d,RmnfaultList,patLoop,patList.size(),cirInfo);
            //CheckFComp(SFD,partialDict_d,Rmnfault_d,RmnfNum_d,RmnfaultList,patLoop,patList.size(),cirInfo,1);
            // ***********************************************

            // Dynamic Shared Memory malloc
            sharedSize = sizeof(PatValue)*(arg->APD_thNum*4*2) +
                         sizeof(char)*(4*paraPatNum) +
                         sizeof(unsigned int)*(3+(paraPatNum+2)*arg->APD_thNum);
            actualPathDelayCal<<<arg->APD_bkNum,arg->APD_thNum,sharedSize>>>(gTypeDum_d,gFiDum_d,foArrayDum_d,foIdxArrayDum_d,foOffsetDum_d,at_d,Ttc_d,dList_d,
                                                                           gStrOnLvlDum_d,val_d,fList_d,Rmnfault_d,RmnfNum_d,partialDict_d,twoLvlval_d,
                                                                           (float*)&twoLvlval_d[(sizeof(PatValue)/sizeof(unsigned int))*(cirInfo->gatesPerLvl)*arg->APD_bkNum*2*2*TFS_thGroup],
                                                                           twoLvlfG_d,EventList_d,fLvl_d,ATUB_d,PT_UBLB_d,arg->delta);
            if(iterNum > 0){
                SFDAnalysis<<<SFD_bkNum,SFD_thNum>>>(partialDict_d,SFD_d,SFD_z,fMask_d,LBRmnfault_d,LBRmnfNum_d,pRdn_d,patList.size(),patLoop,iterNum,2);
                cudaThreadSynchronize();
                SFDRdnPatBuild<<<SFD_bkNum,SFD_thNum>>>(partialDict_d,SFD_d,SFD_z,LBRmnfault_d,LBRmnfNum_d,pRdn_d,patList.size(),fMask_d,patLoop,2);
                SetRedundantPat(pRdn_d,patList,patLoop);
            }
            else{ // first iteration, don't have redundant pattern ID
                SFDAnalysis<<<SFD_bkNum,SFD_thNum>>>(partialDict_d,SFD_d,SFD_z,fMask_d,Rmnfault_d,RmnfNum_d,pRdn_d,patList.size(),patLoop,iterNum,2);
                cudaThreadSynchronize();
            }
            OneCheckCal(SFD,patList,RmnfaultList,essPat,patLoop);
            // End of pattern Loop
        }
        // All the pattern loop has been Sim or All the fault has been detected twice
        // Identify redundant fault
        CompactRedundantFault(SFD,fRdn_d,faultList,iterNum,DSMfNum);
        if(arg->DSM_only == false){
            // Delete Redundant Pattern & Sort Pattern
            cout<<" ----------------------------------------------------------\n";
            fout<<" ----------------------------------------------------------\n";
            SortNCompactPattern(patList);
        }
        cudaThreadSynchronize();
        //(cutStopTimer(timer));
        cout<<" ----------------------------------------------------------\n";
        cout<<" |              Compact Iteration "<<setw(3)<<iterNum<<"                     |\n";
        cout<<" | Total Cal Time So far = "<<setw(15)<<(cutGetTimerValue(timer))/1000<<" (s)            |\n";
        cout<<" | Total Cal Patt So far = "<<setw(15)<<patList.size()<<"                |\n";
        cout<<" ----------------------------------------------------------\n";
        fout<<" ----------------------------------------------------------\n";
        fout<<" |              Compact Iteration "<<setw(3)<<iterNum<<"                     |\n";
        fout<<" | Total Cal Time So far = "<<setw(15)<<(cutGetTimerValue(timer))/1000<<" (s)            |\n";
        fout<<" | Total Cal Patt So far = "<<setw(15)<<patList.size()<<"                |\n";
        fout<<" ----------------------------------------------------------\n";
        iterNum++;
        if(patList[patList.size()-1]->one_check > 0 || arg->DSM_only == true){ // no redundant pattern left
            break;
        }
    }
    if(arg->DSM_only == false)
        DumpPattern(patList);
    cout << " ==========================================================" << endl;
    cout << " =                  Finish Cuda Sim                       =" << endl;
    cout << " ==========================================================" << endl;
    fout << " ==========================================================" << endl;
    fout << " =                  Finish Cuda Sim                       =" << endl;
    fout << " ==========================================================" << endl;
    cout<<" | Circuit: "<<pCir->getModRoot()->getName()<<endl;;
    fout<<" | Circuit: "<<pCir->getModRoot()->getName()<<endl;;
    cout<<" | Total Fault: "<<cirInfo->fNum<<endl;
    fout<<" | Total Fault: "<<cirInfo->fNum<<endl;
    cout<<" | PATTERN Size: "<<cirInfo->patNum<<"  --> Test Group Size: "<<(cirInfo->patNum-1)/paraPatNum + 1<<endl;
    fout<<" | PATTERN Size: "<<cirInfo->patNum<<"  --> Test Group Size: "<<(cirInfo->patNum-1)/paraPatNum + 1<<endl;
    cout<<" | PATTERN Selected Size: "<<patList.size()<<endl;
    fout<<" | PATTERN Selected Size: "<<patList.size()<<endl;
    cout<<" | Circuit input: "<<cirInfo->piNum + cirInfo->ppiNum<<endl;
    fout<<" | Circuit input: "<<cirInfo->piNum + cirInfo->ppiNum<<endl;
    cout<<" | Circuit Size: "<<cirInfo->OrigateNum<<endl;
    fout<<" | Circuit Size: "<<cirInfo->OrigateNum<<endl;
    cout<<" | Circuit Level: "<<cirInfo->cirlvl<<endl;
    fout<<" | Circuit Level: "<<cirInfo->cirlvl<<endl;
    cout<<" | Circuit Max Gate in Level: "<<cirInfo->gatesPerLvl<<endl;
    fout<<" | Circuit Max Gate in Level: "<<cirInfo->gatesPerLvl<<endl;
    cout<<" | Compact Iteration: "<<iterNum<<endl;
    fout<<" | Compact Iteration: "<<iterNum<<endl;
    cout<<" | DSM Coverage: "<<(float)DSMfNum/cirInfo->fNum*100<<" %"<<endl;
    fout<<" | DSM Coverage: "<<(float)DSMfNum/cirInfo->fNum*100<<" %"<<endl;
    fout.close();
    (cutDeleteTimer(timer));
    //{{{ cudaFree
    cudaUnbindTexture(cirInfo_t);
    cudaUnbindTexture(gDum2Ori_t);
    cudaFree(cirInfo_d);
    cudaFree(gDum2Ori_d);
    // Ori Circuit
    cudaFree(gTypeOri_d);
    cudaFree(gFiOri_d);
    cudaFree(gStrOnLvlOri_d);
    // Dum Circuit
    cudaFree(gTypeDum_d);
    cudaFree(gFiDum_d);
    cudaFree(gStrOnLvlDum_d);
    // Fanout
    cudaFree(foArrayDum_d);
    cudaFree(foIdxArrayDum_d);
    cudaFree(foOffsetDum_d);
    // delay and patcudaFree(h delay
    cudaFree(dList_d);
    cudaFree(PT_UBLB_d);
    cudaFree(ATUB_d);
    cudaFree(Ttc_d);
    cudaFree(at_d);
    // value
    cudaFree(val_d);
    // dictionary
    cudaFree(partialDict_d);
    // fault
    cudaFree(fList_d);

    // for pdSim
    cudaFree(fLvl_d);
    cudaFree(twoLvlval_d);
    cudaFree(twoLvlat_d);
    cudaFree(twoLvlfG_d);
    //cudaFree(Rmnfault_d);
    //}}}
}
///}}}
//{{{  __global__ void staticBoundAnalysis()
__global__ void staticBoundAnalysis(unsigned int* gTypeOri_d, float* dList_d,unsigned int* foArrayOri_d,unsigned int* foIdxArrayOri_d,unsigned int* foOffsetOri_d,float* PT_UBLB_d,float* Ttc_d,
                          unsigned int* gFiOri_d,unsigned int* gStrOnLvlOri_d,float* ATUB_d){
    extern __shared__ float longestPath_s[];
    int thId = threadIdx.x;
    int patSize;
    int loop;
    unsigned int gateId;
    if(blockIdx.x == 0){    // PTUB/PTLB Calculation
        //******* Initialize last two level ***********
        for(int i = tex1Dfetch(cirInfo_t,6)-1; i >= tex1Dfetch(cirInfo_t,6)-2; --i){
            unsigned int gStrCurrLvl = gStrOnLvlOri_d[i];
            unsigned int gStrNextLvl = gStrOnLvlOri_d[i+1];
            loop = (gStrNextLvl - gStrCurrLvl-1)/SBA_thNum + 1;
            for(int m = 0 ; m < loop; ++m){
                if(thId + m*SBA_thNum < gStrNextLvl - gStrCurrLvl ){
                    gateId = thId + m*SBA_thNum + gStrCurrLvl;
                    PT_UBLB_d[gateId*4 + 0] = 0.0;
                    PT_UBLB_d[gateId*4 + 1] = 0.0;
                    PT_UBLB_d[gateId*4 + 2] = 0.0;
                    PT_UBLB_d[gateId*4 + 3] = 0.0;
                }
            }
            __syncthreads();

        }
        // ************ calculate PT UB/LB *****************
        for(int i =tex1Dfetch(cirInfo_t,6)-3; i >= 0; --i){
            __syncthreads();
            unsigned int gStrCurrLvl = gStrOnLvlOri_d[i];
            unsigned int gStrNextLvl = gStrOnLvlOri_d[i+1];
            loop = (gStrNextLvl - gStrCurrLvl-1)/SBA_thNum + 1;
            for(int m = 0 ; m < loop; ++m){
                if(thId + m*SBA_thNum < gStrNextLvl - gStrCurrLvl ){
                    gateId = thId + m*SBA_thNum + gStrCurrLvl;
                    int foNum;
                    if(gateId+1 != tex1Dfetch(cirInfo_t,9))
                        foNum = foOffsetOri_d[gateId+1] -foOffsetOri_d[gateId];
                    else
                        foNum =tex1Dfetch(cirInfo_t,9) - foOffsetOri_d[gateId];
                    float maxRPT=0.0;
                    float minRPT=1000.0;
                    float maxFPT=0.0;
                    float minFPT=1000.0;
                    for(int j = 0 ; j < foNum; ++j){
                        int fogIdx =  foArrayOri_d[foOffsetOri_d[gateId]+j]; // fanout gate indexs
                        int fopIdx =  foIdxArrayOri_d[foOffsetOri_d[gateId]+j]; // pin number of  gateul's
                        if(isInv(gTypeOri_d[fogIdx])){
                            if(maxRPT < PT_UBLB_d[fogIdx*4 + 2] + dList_d[fogIdx*8 + 2*fopIdx +1])
                                maxRPT = PT_UBLB_d[fogIdx*4 + 2] + dList_d[fogIdx*8 + 2*fopIdx +1];
                            if(minRPT > PT_UBLB_d[fogIdx*4 + 3] + dList_d[fogIdx*8 + 2*fopIdx +1])
                                minRPT = PT_UBLB_d[fogIdx*4 + 3] + dList_d[fogIdx*8 + 2*fopIdx +1];
                            if(maxFPT < PT_UBLB_d[fogIdx*4 + 0] + dList_d[fogIdx*8 + 2*fopIdx +0])
                                maxFPT = PT_UBLB_d[fogIdx*4 + 0] + dList_d[fogIdx*8 + 2*fopIdx +0];
                            if(minFPT > PT_UBLB_d[fogIdx*4 + 1] + dList_d[fogIdx*8 + 2*fopIdx +0])
                                minFPT = PT_UBLB_d[fogIdx*4 + 1] + dList_d[fogIdx*8 + 2*fopIdx +0];
                        }
                        else{
                            if(maxRPT < PT_UBLB_d[fogIdx*4 + 0] + dList_d[fogIdx*8 + 2*fopIdx +0])
                                maxRPT = PT_UBLB_d[fogIdx*4 + 0] + dList_d[fogIdx*8 + 2*fopIdx +0];
                            if(minRPT > PT_UBLB_d[fogIdx*4 + 1] + dList_d[fogIdx*8 + 2*fopIdx +0])
                                minRPT = PT_UBLB_d[fogIdx*4 + 1] + dList_d[fogIdx*8 + 2*fopIdx +0];
                            if(maxFPT < PT_UBLB_d[fogIdx*4 + 2] + dList_d[fogIdx*8 + 2*fopIdx +1])
                                maxFPT = PT_UBLB_d[fogIdx*4 + 2] + dList_d[fogIdx*8 + 2*fopIdx +1];
                            if(minFPT > PT_UBLB_d[fogIdx*4 + 3] + dList_d[fogIdx*8 + 2*fopIdx +1])
                                minFPT = PT_UBLB_d[fogIdx*4 + 3] + dList_d[fogIdx*8 + 2*fopIdx +1];
                        }
                    }
                    PT_UBLB_d[gateId*4 + 0] = maxRPT;
                    PT_UBLB_d[gateId*4 + 1] = minRPT;
                    PT_UBLB_d[gateId*4 + 2] = maxFPT;
                    PT_UBLB_d[gateId*4 + 3] = minFPT;
                }
            }
        }
    }
    else{   // ATUB Calculation
        // ************** Eval AT ***********************
        loop = (gStrOnLvlOri_d[1] - 1)/SBA_thNum + 1;
        for(int j = 0 ; j < loop;j++){
            if(thId + j*SBA_thNum < gStrOnLvlOri_d[1] ){
                gateId = thId + j*SBA_thNum;
                ATUB_d[gateId*2 + 0] = dList_d[gateId*8 + 2*0 + 0];
                ATUB_d[gateId*2 + 1] = dList_d[gateId*8 + 2*0 + 1];
            }
        }
        float maxRAT;
        float maxFAT;
        float maxT;
        for(int i = 1 ; i < tex1Dfetch(cirInfo_t,6) - 1;++i){
            __syncthreads();
            unsigned int gStrCurrLvl = gStrOnLvlOri_d[i];
            unsigned int gStrNextLvl = gStrOnLvlOri_d[i+1];
            loop = (gStrNextLvl - gStrCurrLvl-1)/SBA_thNum + 1;
            for(int m = 0 ; m < loop; ++m){
                if(thId + m*SBA_thNum < gStrNextLvl - gStrCurrLvl  ){
                    gateId = thId + m*SBA_thNum + gStrCurrLvl;
                    char fiNum = getFiNum(gTypeOri_d[gateId]);
                    maxRAT = 0.0;
                    maxFAT = 0.0;
                    for(char j = 0 ; j < fiNum; ++j){
                        int figId = gFiOri_d[gateId*4 + j];
                        if(isInv(gTypeOri_d[gateId])){ // gate has invert
                            if(maxRAT < ATUB_d[figId*2 + 1] + dList_d[gateId*8 + j*2 + 0])
                                maxRAT = ATUB_d[figId*2 + 1] + dList_d[gateId*8 + j*2 + 0];
                            if(maxFAT < ATUB_d[figId*2 + 0] + dList_d[gateId*8 + j*2 + 1])
                                maxFAT = ATUB_d[figId*2 + 0] + dList_d[gateId*8 + j*2 + 1];
                        }
                        else{
                            if(maxRAT < ATUB_d[figId*2 + 0] + dList_d[gateId*8 + j*2 + 0])
                                maxRAT = ATUB_d[figId*2 + 0] + dList_d[gateId*8 + j*2 + 0];
                            if(maxFAT < ATUB_d[figId*2 + 1] + dList_d[gateId*8 + j*2 + 1])
                                maxFAT = ATUB_d[figId*2 + 1] + dList_d[gateId*8 + j*2 + 1];

                        }
                    }
                    ATUB_d[gateId*2 + 0] = maxRAT;
                    ATUB_d[gateId*2 + 1] = maxFAT;
                    maxT = (maxT > maxRAT ? maxT : maxRAT);
                    maxT = (maxT > maxFAT ? maxT : maxFAT);
                }
            }
        }
        // ************ find longest path *************
        longestPath_s[thId] = maxT;
        __syncthreads();
        for(unsigned int j = SBA_thNum/2 ; j >0; j>>= 1){
            if(thId < j){
                float t0 = longestPath_s[thId];
                float t1 = longestPath_s[thId+j];
                longestPath_s[thId] = t0 > t1 ? t0:t1;
            }
            __syncthreads();
        }
        // This will be transfered back to CPU
        Ttc_d[0] = longestPath_s[0];
    }
}
//}}}
//{{{ __global__ void logicSim()
__global__ void  logicSim(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,unsigned int* gStrOnLvlOri_d,PatValue* pat_t0_d,PatValue* pat_t1_d,PatValue* pat_t0_z,PatValue* pat_t1_z,
                          PatValue* val_d,unsigned int* Rmnfault_d,unsigned int* Rmnfault_z,unsigned int* RmnfNum_d,unsigned int RmnfNum,unsigned int RmnpNum,int patLoop){
    unsigned int totPatNum = (RmnpNum - 1)/paraPatNum + 1;
    // Idle block just return
    if(patLoop + blockIdx.x >= totPatNum)
        return;
    // Initialize Rmnfault_d array
    int loop = (RmnfNum - 1)/(LS_bkNum*LS_thNum) + 1;
    for(int i = 0 ; i < loop ; ++i){
        if(i*LS_bkNum*LS_thNum + blockIdx.x*LS_thNum + threadIdx.x < RmnfNum){
            Rmnfault_d[i*LS_bkNum*LS_thNum + blockIdx.x*LS_thNum + threadIdx.x] = Rmnfault_z[i*LS_bkNum*SBA_thNum + blockIdx.x*LS_thNum + threadIdx.x];
        }
        if(i*LS_bkNum*LS_thNum + blockIdx.x*LS_thNum + threadIdx.x ==0){
            RmnfNum_d[0] = RmnfNum;
        }
    }
    __shared__ unsigned int gFiOri_s[LS_thNum*4];
    __shared__ unsigned int gTypeOri_s[LS_thNum];
    int thId = threadIdx.x;
    unsigned int gatesPerLvl = tex1Dfetch(cirInfo_t,7);
    // ****** zero copy m patterns **************
    int patSize = (tex1Dfetch(cirInfo_t,3) + tex1Dfetch(cirInfo_t,4))*2;
    loop = (patSize - 1)/LS_thNum + 1;
    if(patLoop + LS_bkNum + blockIdx.x < totPatNum){
        for(int i = 0 ; i < loop ; ++i){
            if(thId + i * LS_thNum < patSize){
                pat_t0_d[thId + i * LS_thNum + ((patLoop+1)%2)*patSize*LS_bkNum + blockIdx.x * patSize] = pat_t0_z[thId + i * LS_thNum + (patLoop + LS_bkNum + blockIdx.x) * patSize];
                pat_t1_d[thId + i * LS_thNum + ((patLoop+1)%2)*patSize*LS_bkNum + blockIdx.x * patSize] = pat_t1_z[thId + i * LS_thNum + (patLoop + LS_bkNum + blockIdx.x) * patSize];
            }
        }
    }
    // *******************************************
    loop = (gStrOnLvlOri_d[1] - 1)/LS_thNum + 1;
    unsigned int gateId;
    // ******* set t0 & t1 pattern on PI/PPI*********
    val_d = &val_d[tex1Dfetch(cirInfo_t,9)*4*blockIdx.x]; // val_d position for block
    for(int m = 0 ; m < loop; ++m){
        if(thId + m*LS_thNum < tex1Dfetch(cirInfo_t,3) + tex1Dfetch(cirInfo_t,4)){
            val_d[(thId + m*LS_thNum) * 4 + 0] = pat_t0_d[(patLoop%2)*patSize*LS_bkNum + blockIdx.x*patSize + (thId + m*LS_thNum) * 2 + 0];
            val_d[(thId + m*LS_thNum) * 4 + 1] = pat_t0_d[(patLoop%2)*patSize*LS_bkNum + blockIdx.x*patSize + (thId + m*LS_thNum) * 2 + 1];
            val_d[(thId + m*LS_thNum) * 4 + 2] = pat_t1_d[(patLoop%2)*patSize*LS_bkNum + blockIdx.x*patSize + (thId + m*LS_thNum) * 2 + 0];
            val_d[(thId + m*LS_thNum) * 4 + 3] = pat_t1_d[(patLoop%2)*patSize*LS_bkNum + blockIdx.x*patSize + (thId + m*LS_thNum) * 2 + 1];
        }
    }
    __syncthreads();
    // hold or capture of m patterns in time frame one is saved in the last index of pat_t1_d
    // that is, the h_ of last PPI in time frame one
    // each bit of hold_capture represent hold(0) or capture(1) of m pattern
    // this will affect how PPI perform evaluation
    PatValue hold_capture = val_d[(tex1Dfetch(cirInfo_t,3)+tex1Dfetch(cirInfo_t,4))*4-1];
    // ********** Eval t0 Val **************
    // from lvel 1 to last level
    for(int i = 1 ; i < tex1Dfetch(cirInfo_t,6); ++i){
        unsigned int currLvlStr = gStrOnLvlOri_d[i];
        unsigned int nextLvlStr = gStrOnLvlOri_d[i+1];
        unsigned int nGatesInLvl = nextLvlStr - currLvlStr;
        loop = (nGatesInLvl-1)/LS_thNum + 1;
        for(int m = 0; m < loop; ++m){
            if(m*LS_thNum  < nGatesInLvl){
                int startGateId = currLvlStr + m*LS_thNum;
                // ****** coalesing read gType & gFi to share memory ******
                int gateDataSize;
                if((nextLvlStr - startGateId) < LS_thNum)
                    gateDataSize = (nextLvlStr- startGateId)*4;
                else
                    gateDataSize = LS_thNum*4;
                for(int n = 0 ; n < (gateDataSize-1)/LS_thNum + 1; ++n){
                    if( n*LS_thNum + thId < gateDataSize )
                        gFiOri_s[thId+n*LS_thNum] = gFiOri_d[startGateId*4 + thId+n*LS_thNum ];
                }
                if(thId < gateDataSize/4){
                    gTypeOri_s[thId] = gTypeOri_d[startGateId + thId];
                }
            }
            __syncthreads();
            // ******** Eval time frame 0****************
            if(thId + m*LS_thNum < nGatesInLvl){
                gateId = currLvlStr +  m*LS_thNum + thId;
                evalGate(gateId,gTypeOri_s[thId],gFiOri_s[thId*4+0],gFiOri_s[thId*4+1],gFiOri_s[thId*4+2],gFiOri_s[thId*4+3],val_d,hold_capture,0); // eval time frame 0
            }
        }
        __syncthreads();
    }
    // ********** Eval t1 Val **************
    // use level 0 Eval to set PPI t1 pattern
    for(int i = 0 ; i < tex1Dfetch(cirInfo_t,6); ++i){
        __syncthreads();
        unsigned int currLvlStr = gStrOnLvlOri_d[i];
        unsigned int nextLvlStr = gStrOnLvlOri_d[i+1];
        unsigned int nGatesInLvl = nextLvlStr - currLvlStr;
        loop = (nGatesInLvl-1)/LS_thNum + 1;
        for(int m = 0; m < loop; ++m){
            if(m*LS_thNum < nGatesInLvl){
                int startGateId = currLvlStr + m*LS_thNum;
                // ****** coalesing read gType & gFi to share memory ******
                int gateDataSize;
                if((nextLvlStr - startGateId) < LS_thNum)
                    gateDataSize = (nextLvlStr - startGateId)*4;
                else
                    gateDataSize = LS_thNum*4;
                for(int n = 0 ; n < (gateDataSize-1)/LS_thNum + 1; ++n){
                    if( n*LS_thNum + thId < gateDataSize )
                        gFiOri_s[thId+n*LS_thNum] = gFiOri_d[startGateId*4 + thId+n*LS_thNum ];
                }
                if(thId < gateDataSize/4){
                    gTypeOri_s[thId] = gTypeOri_d[startGateId + thId];
                }
            }
            __syncthreads();
            // ******** Eval time frame 1 ****************
            if(thId + m*LS_thNum < nGatesInLvl){
                gateId = currLvlStr +  m*LS_thNum + thId;
                evalGate(gateId,gTypeOri_s[thId],gFiOri_s[thId*4+0],gFiOri_s[thId*4+1],gFiOri_s[thId*4+2],gFiOri_s[thId*4+3],val_d,hold_capture,1); // eval time frame 1
            }
        }
    }
}
//}}}
//{{{ __global__ void dynamicBoundAnalysis()
__global__ void dynamicBoundAnalysis(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,float* at_d,unsigned int* gStrOnLvlOri_d,PatValue* val_d,float* dList_d,int currLvl){
    __shared__ PatValue   fival_s[DBA_thNum/paraPatNum*4*4];        // fanin val may have 4 fanin in maximum; 4 logic value= t0_l_ t0_h_ t1_l_ t1_h_
    __shared__ PatValue   currval_s[DBA_thNum/paraPatNum*4];        // fanin val may have 4 fanin in maximum
    __shared__ unsigned int gTypeOri_s[DBA_thNum/paraPatNum];
    __shared__ float fiat_s[(DBA_thNum/paraPatNum)*paraPatNum*4];   // fanin arrival time may have 4 fanin in maximum
    __shared__ float dList_s[DBA_thNum/paraPatNum*4*2];             // every gate may  have 4 fanin and each have rising/falling
    int thIdonG = threadIdx.x % paraPatNum;  // thread index on gate
    int gIdonB  = threadIdx.x / paraPatNum;  // gate Id on Block

    // DBA_thNum/paraPatNum = number of gates a block can handle
    int gNumInbk = (DBA_thNum/paraPatNum);      // Number of gates processed by a block
    int gOffset = gNumInbk*DBA_bkNum;           // Number of gates jump after current gate
    unsigned int gStrCurrLvl = gStrOnLvlOri_d[currLvl];
    unsigned int gStrNextLvl = gStrOnLvlOri_d[currLvl + 1];
    int bkLoop = (gStrNextLvl - gStrCurrLvl-1)/gOffset + 1; // block loop
    for(int i = 0 ; i < bkLoop;++i){
        __syncthreads();     // sync all threads
        if(blockIdx.x*gNumInbk + i*gOffset + gStrCurrLvl < gStrNextLvl){
            unsigned int startGateId = gStrCurrLvl + blockIdx.x*gNumInbk + i*gOffset;
            // ********** coalesing read curr gate Val, gType, Delay into share mem ***************
            // using all threads in a block
            int gateDataSize;
            if(gStrNextLvl - startGateId > gNumInbk)
                gateDataSize = gNumInbk;
            else
                gateDataSize = (gStrNextLvl-startGateId);

            if(threadIdx.x < gateDataSize){
                gTypeOri_s[threadIdx.x] = gTypeOri_d[startGateId + threadIdx.x];
            }
            if(threadIdx.x < gateDataSize*5 && threadIdx.x >= gateDataSize){
                currval_s[threadIdx.x-gateDataSize] = val_d[startGateId*4+threadIdx.x-gateDataSize];
            }
            if(threadIdx.x < gateDataSize*13 && threadIdx.x >= gateDataSize*5 ){
                dList_s[threadIdx.x-gateDataSize*5] = dList_d[startGateId*4*2+threadIdx.x-gateDataSize*5];
            }
            // ********** coalescing read Fi AT and Fi val of current gate ************
            // Every 32/64 threads will be reponsible for its gates
            unsigned int gateId = gStrCurrLvl + i*gOffset + blockIdx.x*gNumInbk + gIdonB;
            if(gateId < gStrNextLvl){
                for(int j = 0 ; j < 4; ++j){
                    unsigned int figateId = gFiOri_d[gateId*4 + j];
                    if(figateId != ~0){
                       if(currLvl == 0)
                            fiat_s[gIdonB*paraPatNum*4 + thIdonG*4 + j] = 0.0;
                        else
                            fiat_s[gIdonB*paraPatNum*4 + thIdonG*4 + j] = at_d[figateId*paraPatNum + thIdonG];
                        if(thIdonG < 4){
                            fival_s[gIdonB*4*4 + j*4 + thIdonG] = val_d[figateId*4 + thIdonG];
                        }
                    }
                }
                __syncthreads();

                // ********* Eval AT according to transition *********
                // trans is the transition of gate in claculation
                char trans; // 0 = Rise; 1 = Fall; 2 = static
                trans = getTrans(currval_s[gIdonB*4 + 0],currval_s[gIdonB*4 + 1],currval_s[gIdonB*4 + 2],currval_s[gIdonB*4 + 3],thIdonG);
                if(trans != 2){ // has transition
                    char fiNum = getFiNum(gTypeOri_s[gIdonB]);
                    bool isCtrl = getCtrl(gTypeOri_s[gIdonB],trans); // is trans ctrl value?
                    // trType is the transition we want to find in fanin gate
                    char trType = transType(gTypeOri_s[gIdonB],trans); // 0 = fin rising ; 1 = fin falling ; 2 = fin any transition
                    char fitr[4] = {3,3,3,3};
                    for(char fi = 0 ; fi < fiNum ; ++fi){
                        fitr[fi] = getTrans(fival_s[gIdonB*4*4 + fi*4 + 0],fival_s[gIdonB*4*4 + fi*4 + 1],fival_s[gIdonB*4*4 + fi*4 + 2],fival_s[gIdonB*4*4 + fi*4 + 3],thIdonG);
                    }
                    float gAT;
                    if(isCtrl){ // find ctrl value arrived fastest
                        gAT = 999999.9;
                        for(char fi = 0 ; fi < fiNum ; ++fi){
                            if((trType == fitr[fi] || trType == 2) && gAT > fiat_s[gIdonB*paraPatNum*4 + thIdonG*4 + fi] + dList_s[gIdonB*4*2 + fi*2 + trans] ){
                                gAT = fiat_s[gIdonB*paraPatNum*4 + thIdonG*4 + fi] + dList_s[gIdonB*4*2 + fi*2 + trans];
                            }
                        }
                    }
                    else{   // find non ctrl value arrived latest
                        gAT = 0.0;
                        for(char fi = 0 ; fi < fiNum ; ++fi){
                            if((trType == fitr[fi] || trType == 2) && gAT < fiat_s[gIdonB*paraPatNum*4 + thIdonG*4 + fi] + dList_s[gIdonB*4*2 + fi*2 + trans]){
                                gAT = fiat_s[gIdonB*paraPatNum*4 + thIdonG*4 + fi] + dList_s[gIdonB*4*2 + fi*2 + trans];
                            }
                        }
                    }
                    at_d[gateId*paraPatNum + thIdonG]  = gAT;
                }
                else{   // no transition
                    at_d[gateId*paraPatNum + thIdonG]  = -1.0;
                }

                //**********************************************
            }
        }
    }
}
//}}}
//{{{ __global__ void evalLBCriteria()
__global__ void evalLBCriteria(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,float* at_d,float* ATUB_d,float* PT_UBLB_d,float* Ttc_d,float* dList_d,unsigned int* gStrOnLvlOri_d,
                              PatValue* val_d,unsigned int* fList_d,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,bool* fRdn_d,unsigned int iterNum,float delta){
    // every thread response for eval a fault's criteria
    unsigned int RmnfNum = RmnfNum_d[0];
    int loop = (RmnfNum - 1) / (EVB_thNum*EVB_bkNum) + 1;
    __shared__ int fList_s[EVB_thNum*3];
    __shared__ PatValue fval_s[EVB_thNum*4];
    for(int i = 0 ; i < loop ; ++i){
        // sync to prevent data in shared mem was refleshed
        __syncthreads();
        // ************  coalesing fGate Data to shared *************
        unsigned int fId;
        for(int j = 0 ; j < 4 ;++j){
            // using 4 threads to move 1 gate's value
            if(i*EVB_thNum*EVB_bkNum + blockIdx.x*(EVB_thNum) + j*(EVB_thNum>>2) + (threadIdx.x>>2) < RmnfNum &&
                    j*(EVB_thNum>>2) + (threadIdx.x>>2) < EVB_thNum){
                fId = Rmnfault_d[i*EVB_thNum*EVB_bkNum + blockIdx.x*(EVB_thNum) + j*(EVB_thNum>>2) + (threadIdx.x>>2)];
                int fGate = tex1Dfetch(gDum2Ori_t,fList_d[fId*3 + 2]);
                int fLine = fList_d[fId*3 + 1] -1;
                int fType = fList_d[fId*3 + 0];
                if(((threadIdx.x)&0x03) == 0){
                    fList_s[(j*(EVB_thNum>>2) + (threadIdx.x>>2))*3+2] = fGate;
                    fList_s[(j*(EVB_thNum>>2) + (threadIdx.x>>2))*3+1] = fLine;
                    fList_s[(j*(EVB_thNum>>2) + (threadIdx.x>>2))*3+0] = fType;
                    //printf("j:%d blk:%d thId:%d idx:%d\n",j,blockIdx.x,threadIdx.x,(j*(EVB_thNum>>2) + (threadIdx.x>>2)));
                }
                if(fLine == -1){ // output fault
                    fval_s[(j*(EVB_thNum>>2) + (threadIdx.x>>2))*4 + (threadIdx.x&0x03)] = val_d[fGate*4 + (threadIdx.x&0x03)];
                }
                else{
                    fGate = gFiOri_d[fGate*4 + fLine];
                    fval_s[(j*(EVB_thNum>>2) + (threadIdx.x>>2))*4 + (threadIdx.x&0x03)] = val_d[fGate*4 + (threadIdx.x&0x03)];
                }
            }
        }
        __syncthreads();

        if(i*EVB_thNum*EVB_bkNum + blockIdx.x*EVB_thNum + threadIdx.x < RmnfNum){
            // every thread get one fault to evaluate
            fId = Rmnfault_d[i*EVB_thNum*EVB_bkNum + blockIdx.x*EVB_thNum + threadIdx.x];
            int fGate = fList_s[threadIdx.x*3 + 2];
            int fLine = fList_s[threadIdx.x*3 + 1];
            int fType = fList_s[threadIdx.x*3 + 0];
            float Ttc = Ttc_d[0]*1.1;
            if(fLine == -1){ // output fault
                // loop for m patterns
                for(int patIdx = 0 ; patIdx < paraPatNum; ++patIdx){
                    if(getTrans(fval_s[threadIdx.x*4 + 0],fval_s[threadIdx.x*4 + 1],fval_s[threadIdx.x*4 + 2],fval_s[threadIdx.x*4 + 3],patIdx) == fType ){ // fault active
                        if(iterNum > 0 && fRdn_d[fId]){
                            partialDict_d[fId*paraPatNum + patIdx] = 2; // possible TRF detected
                        }
                        else{
                            if((ATUB_d[fGate*2 + fType] - at_d[fGate*paraPatNum + patIdx])/
                                    (Ttc - at_d[fGate*paraPatNum + patIdx] - PT_UBLB_d[fGate*4 + fType*2]) < delta){
                                partialDict_d[fId*paraPatNum + patIdx] = 1; // possible to bo Q
                            }
                            else{
                                partialDict_d[fId*paraPatNum + patIdx] = 0; //  not possible to bo Q
                            }
                        }
                    }
                    else{
                        partialDict_d[fId*paraPatNum + patIdx] = 0;
                    }
                }
            }
            else{ // input fault
                int finGate = gFiOri_d[fGate*4 + fLine];
                unsigned int gType = gTypeOri_d[fGate];
                int inv;
                if((gType >= 10 && gType <= 13) ||
                        (gType >= 18 && gType <= 21) ||
                        (gType >= 25 && gType <= 27) ||
                        (gType == 29 )){
                    inv = 1;
                }
                else{
                    inv = 0;
                }
                // loop for m patterns
                for(int patIdx = 0 ; patIdx < paraPatNum; ++patIdx){
                    if(getTrans(fval_s[threadIdx.x*4 + 0],fval_s[threadIdx.x*4 + 1],fval_s[threadIdx.x*4 + 2],fval_s[threadIdx.x*4 + 3],patIdx) == fType){ // fault active
                        // dict: 0: not long enough; 1: maybe long enough; 2: long enough
                        if(iterNum != 0 && fRdn_d[fId]){   // fault has been drop in previous pattern group
                            partialDict_d[fId*paraPatNum + patIdx] = 2; // possible to be detected
                        }
                        else{
                            if((ATUB_d[finGate*2 + fType] - at_d[finGate*paraPatNum + patIdx])/
                                    (Ttc - at_d[finGate*paraPatNum + patIdx] - dList_d[fGate*8 + fLine*2 + (fType^inv) ] - PT_UBLB_d[fGate*4 + (fType^inv)*2])
                                    < delta){
                                partialDict_d[fId*paraPatNum + patIdx] = 1;
                            }
                            else{
                                partialDict_d[fId*paraPatNum + patIdx] = 0;
                            }
                        }
                    }
                    else{
                        partialDict_d[fId*paraPatNum + patIdx] = 0;
                    }

                }
            }
        }
    }
}
//}}}
//{{{ __global__ void fCompact1()
__global__ void fCompact1(unsigned int* fMask_d,unsigned int* fSum_d, unsigned int* bSum_d,unsigned int* RmnfNum_d){
    // Use Stream Compaction Algorithm to perform fault dropping
    // first level of compaction
    __shared__ unsigned int fSum_s[FC_thNum*2]; // fault sum in every block
    unsigned int fOffset = blockIdx.x*FC_thNum*2; // fault Offset
    unsigned int RmnfNum = RmnfNum_d[0];
    unsigned int eleNum = FC_thNum*2;   // number of element
    int offset = 1;
    char lstMsk = 0;
    for(int i = 0 ; i < 2; ++i){
        if(fOffset + i*FC_thNum + threadIdx.x < RmnfNum){
            fSum_s[i*FC_thNum + threadIdx.x] = fMask_d[fOffset + i*FC_thNum + threadIdx.x] != ~0 ? 1 : 0;
        }
        else{
            fSum_s[i*FC_thNum + threadIdx.x] = 0;
        }
    }
    __syncthreads();
    lstMsk = fSum_s[FC_thNum*2-1];
    for(int d = eleNum >> 1; d > 0; d >>= 1){
        __syncthreads();
        if(threadIdx.x < d){
            fSum_s[offset*(2*threadIdx.x+2)-1] += fSum_s[offset*(2*threadIdx.x+1)-1];
        }
        offset *= 2;
    }
    if(threadIdx.x == 0){
        fSum_s[eleNum - 1] = 0;
    }
    for(int d = 1; d < eleNum; d*=2){
        offset >>= 1;
        __syncthreads();
        if(threadIdx.x < d){
            unsigned int tmp = fSum_s[offset*(2*threadIdx.x+1)-1];
            fSum_s[offset*(2*threadIdx.x+1)-1] = fSum_s[offset*(2*threadIdx.x+2)-1];
            fSum_s[offset*(2*threadIdx.x+2)-1] += tmp;
        }
    }
    __syncthreads();
    if(threadIdx.x == 0){
        bSum_d[blockIdx.x] = fSum_s[eleNum - 1] + lstMsk;
        //printf("bSum_d[%d]=%d\n",blockIdx.x,bSum_d[blockIdx.x]);
    }
    for(int i = 0 ; i < 2; ++i){
        if(fOffset + i*FC_thNum + threadIdx.x < RmnfNum){
            fSum_d[fOffset + i*FC_thNum + threadIdx.x] = fSum_s[i*FC_thNum + threadIdx.x];
        }
    }
}
//}}}
//{{{ __global__ void fCompact2()
__global__ void fCompact2(unsigned int* fSum_d, unsigned int* bSum_d,unsigned int FC_bkNum){
    // Second level of compaction
    __shared__ unsigned int bSum_s[FC_thNum*2]; // block sum
    unsigned int eleNum = powf(2,ceilf(log2f(FC_bkNum)));
    int offset = 1;
    for(int i = 0 ; i < 2; ++i){
        if(i*FC_thNum + threadIdx.x < FC_bkNum){
            bSum_s[i*FC_thNum + threadIdx.x] = bSum_d[i*FC_thNum + threadIdx.x];
        }
        else
            bSum_s[i*FC_thNum + threadIdx.x] = 0;
    }
    __syncthreads();
    for(int d = eleNum >> 1; d > 0; d >>= 1){
        __syncthreads();
        if(threadIdx.x < d){
            bSum_s[offset*(2*threadIdx.x+2)-1] += bSum_s[offset*(2*threadIdx.x+1)-1];
        }
        offset *= 2;
    }
    if(threadIdx.x == 0)
        bSum_s[eleNum - 1] = 0;
    for(int d = 1; d < eleNum; d*=2){
        offset >>= 1;
        __syncthreads();
        if(threadIdx.x < d){
            unsigned int tmp = bSum_s[offset*(2*threadIdx.x+1)-1];
            bSum_s[offset*(2*threadIdx.x+1)-1] = bSum_s[offset*(2*threadIdx.x+2)-1];
            bSum_s[offset*(2*threadIdx.x+2)-1] += tmp;
        }
    }
    __syncthreads();
    for(int i = 0 ; i < 2; ++i){
        if(i*FC_thNum + threadIdx.x < FC_bkNum){
            bSum_d[i*FC_thNum + threadIdx.x] = bSum_s[i*FC_thNum + threadIdx.x];
        }
    }
}
//}}}
//{{{ __global__ void uniformAdd()
__global__ void uniformAdd(unsigned int* fMask_d,unsigned int* fSum_d, unsigned int* bSum_d,
                          unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,unsigned int* LBRmnfault_d,unsigned int* LBRmnfNum_d,bool afterLB){
    __shared__ unsigned int fSum_s[FC_thNum*2];
    __shared__ unsigned int fMask_s[FC_thNum*2];
    unsigned int foffset = blockIdx.x*FC_thNum*2; // fault Offset
    unsigned int RmnfNum = RmnfNum_d[0];
    unsigned int accSum = bSum_d[blockIdx.x]; // accumulate Sum
    for(int i = 0 ; i < 2; ++i){
        if(foffset + i*FC_thNum + threadIdx.x < RmnfNum){
            fSum_s[i*FC_thNum + threadIdx.x] = fSum_d[foffset + i*FC_thNum + threadIdx.x] + accSum;
            fMask_s[i*FC_thNum + threadIdx.x] = fMask_d[foffset + i*FC_thNum + threadIdx.x];
            if(fMask_s[i*FC_thNum+threadIdx.x] != ~0){
                Rmnfault_d[fSum_s[i*FC_thNum + threadIdx.x]] = fMask_s[i*FC_thNum + threadIdx.x];
                if(afterLB)
                    LBRmnfault_d[fSum_s[i*FC_thNum+threadIdx.x]] = fMask_s[i*FC_thNum + threadIdx.x];
            }
            if(foffset + i*FC_thNum + threadIdx.x == RmnfNum - 1){
                RmnfNum_d[1] = fSum_s[i*FC_thNum + threadIdx.x] + (fMask_s[i*FC_thNum + threadIdx.x] != ~0 ? 1:0);
                if(afterLB)
                    LBRmnfNum_d[0] = fSum_s[i*FC_thNum + threadIdx.x] + (fMask_s[i*FC_thNum + threadIdx.x] != ~0 ? 1:0);
            }
        }
    }
    __syncthreads();

}
//}}}
//{{{ __golbal__ void untimedFaultSim()
// every thread block have multiple thread group, each thread group handle a fault
__global__ void untimedFaultSim(unsigned int* gTypeDum_d,unsigned int* gFiDum_d,unsigned int* foArrayDum_d,unsigned int* foIdxArrayDum_d,unsigned int* foOffsetDum_d,
                      unsigned int* gStrOnLvlDum_d,PatValue* val_d,unsigned int* fList_d,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,
                      PatValue* twoLvlval_d,unsigned int* twoLvlfG_d,unsigned int* EventList_d,unsigned int* fLvl_d){
    extern __shared__ unsigned int sharedMem[];
    unsigned int* foStr_s     = sharedMem;  // save where fo should str & faulty gateId
    unsigned int* foSize_s    = &foStr_s[blockDim.x]; // save foSize & faulty pin of faulty gateId
    unsigned int* eventSize_s = &foSize_s[blockDim.x]; // number of event gate in Event List
    PatValue* detect_s        = (PatValue*)&eventSize_s[2];
    PatValue* fival_s         = &detect_s[blockDim.x];

    unsigned int RmnfNum = RmnfNum_d[1];
    // update New Remain fault Number
    if(blockIdx.x == 0 && threadIdx.x == 0)
        RmnfNum_d[0] = RmnfNum;

    int floop = (RmnfNum - 1)/gridDim.x*TFS_thGroup + 1;
    unsigned int cirLvl = tex1Dfetch(cirInfo_t,6);
    unsigned int gatesPerLvl = tex1Dfetch(cirInfo_t,7);
    unsigned int thIdonF   = threadIdx.x % blockDim.x;
    unsigned int fIdonB    = threadIdx.x / blockDim.x;
    unsigned int fNumInB   = TFS_thGroup;
    twoLvlval_d  = &twoLvlval_d[(blockIdx.x*fNumInB + fIdonB)*gatesPerLvl*2*2];
    twoLvlfG_d   =  &twoLvlfG_d[(blockIdx.x*fNumInB + fIdonB)*gatesPerLvl];
    EventList_d  = &EventList_d[(blockIdx.x*fNumInB + fIdonB)*gatesPerLvl*2];
    for(int i = 0 ; i < floop ; ++i){ // loop for pick fault
        __syncthreads();
        bool dataflag = false;            // represent which data array we current on
        if(i*gridDim.x*fNumInB + blockIdx.x*fNumInB + fIdonB < RmnfNum){
            unsigned int fId = Rmnfault_d[i*gridDim.x*fNumInB + blockIdx.x*fNumInB + fIdonB];
            unsigned int fLvl = fLvl_d[fId];   // fault level
            unsigned int fType = fList_d[fId*3 + 0];
            int          fLine = fList_d[fId*3 + 1] - 1;
            unsigned int fGate = fList_d[fId*3 + 2];
            // fault injection
            unsigned gStrCurrLvl = gStrOnLvlDum_d[fLvl];
            unsigned gStrNextLvl = gStrOnLvlDum_d[fLvl+1];
            unsigned int loop = (gatesPerLvl - 1)/(blockDim.x) + 1;

            for(int j = 0 ; j < loop; ++j){
                if(thIdonF + j*blockDim.x < gatesPerLvl)
                    twoLvlfG_d[thIdonF + j*blockDim.x] = 0;
            }
            loop = (paraPatNum - 1)/ blockDim.x + 1;
            detect_s[fIdonB*blockDim.x + thIdonF] = 0;
            __syncthreads();
            // ********** Set twoLvl value for faulty gate *************
            if(thIdonF == 0){
                if(fLine == -1){ // output fault
                    if(fType == 0){ // rising fault
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 0] = ~0;
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 1] = 0;
                    }
                    else{   // falling fault
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 0] = 0;
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 1] = ~0;
                    }
                }
                else{ // intput fault
                    char fiNum = getFiNum(gTypeDum_d[fGate]);
                    for(char fi = 0 ; fi < fiNum ;++fi){
                        unsigned int figateId = tex1Dfetch(gDum2Ori_t,gFiDum_d[fGate*4+fi]);
                        if(fLine == fi){
                            if(fType == 0){ // slow to  rise fault
                                fival_s[fIdonB*blockDim.x*4*2 + fi*2+0] = ~0;
                                fival_s[fIdonB*blockDim.x*4*2 + fi*2+1] = 0;
                            }
                            else{ // slow to fall fault
                                fival_s[fIdonB*blockDim.x*4*2 + fi*2+0] = 0;
                                fival_s[fIdonB*blockDim.x*4*2 + fi*2+1] = ~0;
                            }
                        }
                        else{
                            fival_s[fIdonB*blockDim.x*4*2 + fi*2+0] = val_d[figateId*4 + 2];
                            fival_s[fIdonB*blockDim.x*4*2 + fi*2+1] = val_d[figateId*4 + 3];
                        }
                    }
                    evalGate(gTypeDum_d[fGate],fival_s[fIdonB*blockDim.x*4*2 + 0],fival_s[fIdonB*blockDim.x*4*2 + 1],
                                               fival_s[fIdonB*blockDim.x*4*2 + 2],fival_s[fIdonB*blockDim.x*4*2 + 3],
                                               fival_s[fIdonB*blockDim.x*4*2 + 4],fival_s[fIdonB*blockDim.x*4*2 + 5],
                                               fival_s[fIdonB*blockDim.x*4*2 + 6],fival_s[fIdonB*blockDim.x*4*2 + 7],
                                               &twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2]);
                }
                if((twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 0] != val_d[tex1Dfetch(gDum2Ori_t,fGate)*4 + 2] ||
                            twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 1] != val_d[tex1Dfetch(gDum2Ori_t,fGate)*4 + 3])){
                    // fault can propogate =>  set foGate effected pin
                    unsigned int foStr = foOffsetDum_d[fGate];
                    unsigned int foEnd = foOffsetDum_d[fGate+1];
                    for(int fo = foStr ; fo < foEnd; ++fo){
                        EventList_d[fo - foStr] = (foArrayDum_d[fo]<<4) | (0x01<<foIdxArrayDum_d[fo]);
                    }
                    eventSize_s[fIdonB] = foEnd - foStr;
                }
                else{
                    eventSize_s[fIdonB] = 0;
                }
                if(eventSize_s[fIdonB] == 0){   // fGate is PO or PPO
                    detect_s[fIdonB*blockDim.x + thIdonF] |= (twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 0] ^
                            val_d[tex1Dfetch(gDum2Ori_t,fGate)*4 + 2]) |
                        (twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 1] ^
                         val_d[tex1Dfetch(gDum2Ori_t,fGate)*4 + 3]);
                }
            }
            __syncthreads();
            // finish fault Injection

            for(int currlvl = fLvl + 1; currlvl < cirLvl; ++currlvl){
                // loop for Lvl on circuit
                __syncthreads();
                if(eventSize_s[fIdonB] == 0){
                    break;
                }
                dataflag = !dataflag;
                unsigned int gStrPrevLvl = gStrOnLvlDum_d[currlvl - 1];
                gStrCurrLvl = gStrOnLvlDum_d[currlvl];
                gStrNextLvl = gStrOnLvlDum_d[currlvl+1];
                // simulate val fiSFD
                loop = (eventSize_s[fIdonB] - 1)/blockDim.x + 1; // loop for event ;
                // ********** Set twoLvl value for gate *************
                for(int j = 0 ; j < loop; ++j){
                    if(j*blockDim.x + thIdonF < eventSize_s[fIdonB]){
                        // use 4-bits to save which pin is faulty pin
                        // use other bits to save faulty gate Id
                        unsigned int gateId = (EventList_d[(!dataflag)*gatesPerLvl + j*blockDim.x + thIdonF]>>4);
                        unsigned int fPin   = (EventList_d[(!dataflag)*gatesPerLvl + j*blockDim.x + thIdonF] & 0x0F);
                        char fiNum = getFiNum(gTypeDum_d[gateId]);
                        for(char fi = 0 ; fi < fiNum; ++fi){
                            unsigned int figateId = gFiDum_d[gateId*4 + fi];
                            // if fanin gate is faulty read value from twoLvlval of the block
                            // else read faulty free value from logic sim
                            if((fPin&(0x01<<fi)) != 0){
                                fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + fi*2+0] = twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 0];
                                fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + fi*2+1] = twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 1];
                            }
                            else{
                                fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + fi*2+0] = val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 2];
                                fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + fi*2+1] = val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 3];
                           }
                        }
                        evalGate(gTypeDum_d[gateId],fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 0],fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 1],
                                 fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 2],fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 3],
                                 fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 4],fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 5],
                                 fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 6],fival_s[fIdonB*blockDim.x*4*2 + thIdonF*8 + 7],
                                 &twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2]);
                        unsigned int foStr = foOffsetDum_d[gateId];
                        unsigned int foEnd = foOffsetDum_d[gateId+1];
                        if(foEnd - foStr != 0){
                            if((twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 0] !=
                                val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 2] ||
                                twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 1] !=
                                val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 3])){
                                // fault can propogate =>  set foGate effected pin
                                for(int fo = foStr ; fo < foEnd; ++fo){
                                    atomicAdd(&twoLvlfG_d[foArrayDum_d[fo]-gStrNextLvl],(0x01<<foIdxArrayDum_d[fo]));
                                }
                            }
                        }
                        else{
                            detect_s[fIdonB*blockDim.x + thIdonF] |= (twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 0] ^
                                    val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 2]) |
                                (twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 1] ^
                                 val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 3]);
                        }
                    }
                }
                __syncthreads();
                // add event List
                if(currlvl+1 < cirLvl){
                    // evaluate a set of gates
                    loop = (eventSize_s[fIdonB] - 1)/blockDim.x + 1;
                    unsigned int eventSize = 0;
                    for(int j = 0 ; j < loop; ++j){
                        __syncthreads();
                        unsigned int Idx = j*blockDim.x + thIdonF;
                        if(Idx < eventSize_s[fIdonB]){
                            unsigned int eventGate = EventList_d[(!dataflag)*gatesPerLvl + Idx]>>4;
                            foStr_s[fIdonB*blockDim.x + thIdonF]  = foOffsetDum_d[eventGate];
                            foSize_s[fIdonB*blockDim.x + thIdonF] = foOffsetDum_d[eventGate+1] - foOffsetDum_d[eventGate];
                        }
                        __syncthreads();
                        if(thIdonF == 0){
                            for(int m = 0 ; m < blockDim.x && j*blockDim.x + m < eventSize_s[fIdonB]; ++m){
                                for(int fo = 0; fo < foSize_s[fIdonB*blockDim.x + m]; ++fo){
                                    if((twoLvlfG_d[foArrayDum_d[foStr_s[fIdonB*blockDim.x + m]+fo]-gStrNextLvl]) != 0){
                                        EventList_d[dataflag*gatesPerLvl + eventSize] = (foArrayDum_d[foStr_s[fIdonB*blockDim.x + m]+fo]<<4) +
                                                                                      (twoLvlfG_d[foArrayDum_d[foStr_s[fIdonB*blockDim.x + m]+fo]-gStrNextLvl]);
                                        twoLvlfG_d[foArrayDum_d[foStr_s[fIdonB*blockDim.x + m]+fo]-gStrNextLvl] = 0;
                                        eventSize++;
                                    }
                                }
                            }
                        }
                        __syncthreads();
                    }
                    if(thIdonF == 0){
                        eventSize_s[fIdonB] = eventSize;
                    }
                }
            }
            // after simulation Check Result
            int offset = 1;
            for(int j = blockDim.x >> 1; j > 0 ; j>>=1){
                if(thIdonF < j){
                    detect_s[fIdonB*blockDim.x + offset*(2*thIdonF+2)-1] |= detect_s[fIdonB*blockDim.x + offset*(2*thIdonF+1)-1];
                }
                offset *= 2;
                __syncthreads();
            }
            loop = (paraPatNum -1)/blockDim.x + 1;
            for(int j = 0 ; j < loop ; ++j){
                if(j*blockDim.x + thIdonF < paraPatNum){
                    if((detect_s[fIdonB*blockDim.x + blockDim.x - 1] & ((PatValue)0x01<<(j*blockDim.x+thIdonF))) == 0){
                        partialDict_d[fId*paraPatNum + j*blockDim.x + thIdonF] = 0;
                    }
                }
            }
        }
    }
}
//}}}
//{{{ __global__ void evalUBCriteria()
__global__ void evalUBCriteria(unsigned int* gTypeOri_d,unsigned int* gFiOri_d,float* at_d,float* ATUB_d,float* PT_UBLB_d,float* Ttc_d,float* dList_d,
                         unsigned int* gStrOnLvlOri_d,unsigned int* fList_d,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,float delta){
    __shared__ unsigned int fList_s[EVB_thNum*3];
    unsigned int RmnfNum = RmnfNum_d[0];
    int loop = (RmnfNum - 1) / (EVB_thNum*EVB_bkNum) + 1;
    unsigned int fId;
    unsigned int thIdonF = threadIdx.x%3;
    unsigned int fIdonB  = threadIdx.x/3;
    unsigned int fNumInB = EVB_thNum/3;
    for(int i = 0 ; i < loop ; ++i){
        __syncthreads();
        // coalesing read fList_d to fList_s share mem first
        int floop = (EVB_thNum -1)/(fNumInB) + 1;
        for(int j = 0 ; j < floop; ++j){
            if(i*EVB_bkNum*EVB_thNum + blockIdx.x*EVB_thNum + j*fNumInB + fIdonB < RmnfNum && j*fNumInB + fIdonB < EVB_thNum){
                fId = Rmnfault_d[i*EVB_bkNum*EVB_thNum + blockIdx.x*EVB_thNum + j*fNumInB + fIdonB];
                fList_s[(j*fNumInB + fIdonB)*3 + thIdonF] = fList_d[fId*3 + thIdonF];
            }
        }
        __syncthreads();
        if(i*EVB_thNum*EVB_bkNum + blockIdx.x*EVB_thNum + threadIdx.x < RmnfNum){
            fId = Rmnfault_d[i*EVB_thNum*EVB_bkNum + blockIdx.x*EVB_thNum + threadIdx.x];
            int fGate = tex1Dfetch(gDum2Ori_t,fList_s[threadIdx.x*3 + 2]);
            int fType = fList_s[threadIdx.x*3 + 0];
            float Ttc = Ttc_d[0]*1.1;
            if(fList_s[threadIdx.x*3 + 1] == 0){ // output fault
                for(int patIdx = 0 ; patIdx < paraPatNum; ++patIdx){
                    if(partialDict_d[fId*paraPatNum + patIdx] == 1 ){  // fault is detected
                        if((ATUB_d[fGate*2 + fType] + PT_UBLB_d[fGate*4 + fType*2] - at_d[fGate*paraPatNum + patIdx] - PT_UBLB_d[fGate*4 + fType*2 + 1])/
                                (Ttc - at_d[fGate*paraPatNum + patIdx] - PT_UBLB_d[fGate*4 + fType*2 + 1]) < delta){
                            partialDict_d[fId*paraPatNum + patIdx] = 2;
                        }
                        else{
                        }
                    }
                    else{
                    }
                }
            }
            else{ // input fault
                int fLine = fList_s[threadIdx.x*3 + 1] -1;
                int finGate = gFiOri_d[fGate*4 + fLine];
                unsigned int gType = gTypeOri_d[fGate];
                int inv;
                if((gType >= 10 && gType <= 13) ||
                        (gType >= 18 && gType <= 21) ||
                        (gType >= 25 && gType <= 27) ||
                        (gType == 29 )){
                    inv = 1;
                }
                else{
                    inv = 0;
                }
                for(int patIdx = 0 ; patIdx < paraPatNum; ++patIdx){
                    if(partialDict_d[fId*paraPatNum + patIdx] == 1){ // Check DSMUB (Use PDLB)
                        if((ATUB_d[finGate*2 + fType] + PT_UBLB_d[fGate*4 + (fType^inv)*2] -
                                    at_d[finGate*paraPatNum + patIdx] - PT_UBLB_d[fGate*4 + (fType^inv)*2 + 1] )/
                                (Ttc - at_d[finGate*paraPatNum + patIdx] - dList_d[fGate*8 + fLine*2 + (fType^inv) ] - PT_UBLB_d[fGate*4 + (fType^inv)*2 + 1])
                                < delta){
                            partialDict_d[fId*paraPatNum + patIdx] = 2;
                        }
                        else{
                        }
                    }
                    else{
                    }

                }
            }
        }
    }
}
//}}}
//{{{ __global__ void actualPathDelayCal()
__global__ void actualPathDelayCal(unsigned int* gTypeDum_d,unsigned int* gFiDum_d,unsigned int* foArrayDum_d,unsigned int* foIdxArrayDum_d,unsigned int* foOffsetDum_d,
                                   float* at_d,float* Ttc_d,float* dList_d,unsigned int* gStrOnLvlDum_d,PatValue* val_d,unsigned int* fList_d,unsigned int* Rmnfault_d,
                                   unsigned int* RmnfNum_d,char* partialDict_d,PatValue* twoLvlval_d,float* twoLvlat_d,unsigned int* twoLvlfG_d,unsigned int* EventList_d,
                                   unsigned int* fLvl_d,float* ATUB_d,float* PT_UBLB_d,float delta){
    // Dynamic shared Mememory malloc
    extern __shared__ PatValue      sharedPatValue[];
    extern __shared__ unsigned int  sharedInt[];
    extern __shared__ char          sharedChar[];
    PatValue*       fival_s     = sharedPatValue;
    float*          maxPD_s     = (float*)&sharedInt[blockDim.x*16]; // only for debug not used
    float*          PDs_s       = &maxPD_s[paraPatNum*blockDim.x]; // Structual longest path
    unsigned int*   eventSize_s = (unsigned int*)&PDs_s[1];
    unsigned int*   detPatNum_s = &eventSize_s[1];
    unsigned int*   foStr_s     = &detPatNum_s[1];
    unsigned int*   foSize_s    = &foStr_s[blockDim.x];
    char*           dict_s      = &sharedChar[blockDim.x*(64+paraPatNum*4+8)+12];
    char*           dictTmp_s   = &dict_s[paraPatNum];
    char*           dictScn_s   = &dictTmp_s[paraPatNum];
    bool*           patDone_s   = (bool*)&dictScn_s[paraPatNum];
    unsigned int RmnfNum = RmnfNum_d[1];
    // update remain fault number
    if(blockIdx.x == 0 && threadIdx.x == 0)
        RmnfNum_d[0] = RmnfNum;
    if(RmnfNum == 0)
        return;
    int floop = (RmnfNum - 1)/gridDim.x + 1;
    float Ttc = Ttc_d[0]*1.1;
    unsigned int cirLvl = tex1Dfetch(cirInfo_t,6);
    unsigned int gatesPerLvl = tex1Dfetch(cirInfo_t,7);
    twoLvlval_d  = &twoLvlval_d[blockIdx.x*gatesPerLvl*2*2];
    twoLvlat_d   = &twoLvlat_d[blockIdx.x*gatesPerLvl*paraPatNum*2];
    twoLvlfG_d   = &twoLvlfG_d[blockIdx.x*gatesPerLvl];
    EventList_d  = &EventList_d[blockIdx.x*gatesPerLvl*2];
    for(int i = 0 ; i < floop ; ++i){ // loop for pick fault
        __syncthreads();
        bool dataflag = false;            // represent which data arry we current on
        if(blockIdx.x + i*gridDim.x < RmnfNum){
            unsigned int fId = Rmnfault_d[blockIdx.x + i*gridDim.x];
            unsigned int fLvl = fLvl_d[fId];   // fault level
            unsigned int fType = fList_d[fId*3 + 0];
            int          fLine = fList_d[fId*3 + 1] - 1;
            unsigned int fGate = fList_d[fId*3 + 2];
            // fault injection
            unsigned gStrCurrLvl = gStrOnLvlDum_d[fLvl];
            unsigned gStrNextLvl = gStrOnLvlDum_d[fLvl+1];
            unsigned int loop = (gatesPerLvl - 1)/(blockDim.x) + 1;
            for(unsigned int j = 0 ; j < loop; ++j){
                if(threadIdx.x + j*blockDim.x < gatesPerLvl)
                    twoLvlfG_d[threadIdx.x + j*blockDim.x] = 0;
            }
            // **************** Compact partial dictionary *****************
            // Compact patId that may detect this fault into the front of the
            // array: dict_s  using stream compaction
            loop = (paraPatNum - 1)/blockDim.x + 1;
            for(unsigned int j = 0 ; j < loop ; ++j){
                if(j*blockDim.x + threadIdx.x < paraPatNum){
                    dictScn_s[j*blockDim.x + threadIdx.x] = partialDict_d[fId*paraPatNum + j*blockDim.x + threadIdx.x] == 1 ? 1 : 0;
                    dictTmp_s[j*blockDim.x + threadIdx.x] = dictScn_s[j*blockDim.x + threadIdx.x];
                }
            }
            __syncthreads();
            int offset = 1;
            for(int j = paraPatNum >> 1; j > 0 ; j>>=1){
                __syncthreads();
                if(threadIdx.x < j){
                    dictScn_s[offset*(2*threadIdx.x+2)-1] += dictScn_s[offset*(2*threadIdx.x+1)-1];
                }
                offset *= 2;
            }
            if(threadIdx.x == 0)
                dictScn_s[paraPatNum-1] = 0;
            for(int j = 1; j < paraPatNum; j*=2){
                offset >>= 1;
                __syncthreads();
                if(threadIdx.x < j){
                    char tmp  = dictScn_s[offset*(2*threadIdx.x+1)-1];
                    dictScn_s[offset*(2*threadIdx.x+1)-1] = dictScn_s[offset*(2*threadIdx.x+2)-1];
                    dictScn_s[offset*(2*threadIdx.x+2)-1] += tmp;
                }
            }
            __syncthreads();
            for(unsigned int j = 0 ; j < loop ; ++j){
                if(j*blockDim.x + threadIdx.x < paraPatNum){
                    if(dictTmp_s[j*blockDim.x + threadIdx.x] == 1)
                        dict_s[dictScn_s[j*blockDim.x + threadIdx.x]] = j*blockDim.x + threadIdx.x;
                    patDone_s[j*blockDim.x + threadIdx.x] = false;
                }
            }
            __syncthreads();
            // ********** End of Compact dictionary ****************

            // ********** Set Two Level Array value for faulty gate *************
            if(threadIdx.x == blockDim.x - 1){ // Use one thread to inject fault
                detPatNum_s[0] = dictScn_s[paraPatNum - 1] + dictTmp_s[paraPatNum - 1]; // number of pattern needs Actual Path delay Cal
                if(fLine == -1){ // output fault
                    if(fType == 0){ // rising fault
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 0] = ~0;
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 1] = 0;
                    }
                    else{   // falling fault
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 0] = 0;
                        twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2 + 1] = ~0;
                    }
                }
                else{ // intput fault
                    char fiNum = getFiNum(gTypeDum_d[fGate]);
                    for(char fi = 0 ; fi < fiNum ;++fi){
                        unsigned int figateId = tex1Dfetch(gDum2Ori_t,gFiDum_d[fGate*4+fi]);
                        if(fLine == fi){
                            if(fType == 0){ // slow to  rise fault
                                fival_s[fi*2+0] = ~0;
                                fival_s[fi*2+1] = 0;
                            }
                            else{ // slow to fall fault
                                fival_s[fi*2+0] = 0;
                                fival_s[fi*2+1] = ~0;
                            }
                        }
                        else{
                            fival_s[fi*2+0] = val_d[figateId*4 + 2];
                            fival_s[fi*2+1] = val_d[figateId*4 + 3];
                        }
                    }
                    evalGate(gTypeDum_d[fGate],fival_s[0],fival_s[1],fival_s[2],fival_s[3],
                             fival_s[4],fival_s[5],fival_s[6],fival_s[7],&twoLvlval_d[dataflag*gatesPerLvl*2 + (fGate-gStrCurrLvl)*2]);
                }
            }
            else if(threadIdx.x == 0){   //  Use one thread to Save Event List
                unsigned int foStr = foOffsetDum_d[fGate];
                unsigned int foEnd = foOffsetDum_d[fGate+1];
                for(int j = foStr ; j < foEnd; ++j){
                    // using last 4 bits to indicate faulty pin
                    EventList_d[j - foStr] = (foArrayDum_d[j]<<4) | (0x01<<foIdxArrayDum_d[j]);
                }
                eventSize_s[0] = foEnd - foStr;
            }
            __syncthreads();
            // *********** Set faulty Lvl Arrival Time ***************
            for(int j = 0 ; j < loop ; ++j){
                if(j*blockDim.x + threadIdx.x < detPatNum_s[0]){
                    char patIdx = dict_s[j*blockDim.x + threadIdx.x];
                    if(fLine != -1 ){ // input fault
                        unsigned int fifGate = tex1Dfetch(gDum2Ori_t,gFiDum_d[fGate*4+fLine]);
                        unsigned int gType = gTypeDum_d[fGate];
                        int inv;
                        if((gType >= 10 && gType <= 13) ||
                                (gType >= 18 && gType <= 21) ||
                                (gType >= 25 && gType <= 27) ||
                                (gType == 29 )){
                            inv = 1;
                        }
                        else{
                            inv = 0;
                        }
                        twoLvlat_d[dataflag*gatesPerLvl*paraPatNum + (fGate-gStrCurrLvl)*paraPatNum + patIdx] = at_d[fifGate*paraPatNum + patIdx] +
                                   dList_d[tex1Dfetch(gDum2Ori_t,fGate)*8 + fLine*2 + (fType^inv)];
                        PDs_s[0] = ATUB_d[fifGate*2 + fType]+ dList_d[tex1Dfetch(gDum2Ori_t,fGate)*8 + fLine*2 + (fType^inv)] +
                                          PT_UBLB_d[tex1Dfetch(gDum2Ori_t,fGate)*4 + (fType^inv)*2];
                    }
                    else{
                        twoLvlat_d[dataflag*gatesPerLvl*paraPatNum + (fGate-gStrCurrLvl)*paraPatNum + patIdx] =
                            at_d[tex1Dfetch(gDum2Ori_t,fGate)*paraPatNum + patIdx];
                        PDs_s[0] = ATUB_d[tex1Dfetch(gDum2Ori_t,fGate)*2 + fType] + PT_UBLB_d[tex1Dfetch(gDum2Ori_t,fGate)*4 + fType*2];
                    }
                }
            }
            __syncthreads();
            // *************** finish fault injection ******************

            float maxPD = 0.0;  // maximum path delay of each thread
            for(int currlvl = fLvl + 1; currlvl < cirLvl; ++currlvl){  // loop for Lvl on circuit
            //for(int currlvl = fLvl + 1; currlvl < fLvl+3; ++currlvl){  // loop for Lvl on circuit
                if(eventSize_s[0] == 0)
                    break;
                __syncthreads();
                dataflag = !dataflag; // switch between two array
                unsigned int gStrPrevLvl = gStrOnLvlDum_d[currlvl - 1];
                gStrCurrLvl = gStrOnLvlDum_d[currlvl];
                gStrNextLvl = gStrOnLvlDum_d[currlvl+1];
                // simulate event gate value
                loop = (eventSize_s[0] - 1)/(blockDim.x) + 1; // loop for event
                for(int j = 0 ; j < loop; ++j){
                    __syncthreads();
                    // ********** Set Two Lvl Array value for gate *************
                    if(j*blockDim.x + threadIdx.x < eventSize_s[0]){
                        unsigned int gateId = (EventList_d[(!dataflag)*gatesPerLvl + j*blockDim.x + threadIdx.x]>>4);
                        // Use 4-bits to represent faulty pin. ex: 0010 means second pi is faulty
                        unsigned int fPin   = (EventList_d[(!dataflag)*gatesPerLvl + j*blockDim.x + threadIdx.x] & 0x0F); // faulty pin
                        foStr_s[threadIdx.x] = gateId;
                        foSize_s[threadIdx.x] = fPin;
                        char fiNum = getFiNum(gTypeDum_d[gateId]);
                        for(char fi = 0 ; fi < fiNum; ++fi){
                            unsigned int figateId = gFiDum_d[gateId*4 + fi];
                            if((fPin&(0x01<<fi)) != 0){ // get fi value from last level array
                                fival_s[threadIdx.x*8 + fi*2+0] = twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 0];
                                fival_s[threadIdx.x*8 + fi*2+1] = twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 1];
                            }
                            else{ // get fi value from logic sim
                                fival_s[threadIdx.x*8 + fi*2+0] = val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 2];
                                fival_s[threadIdx.x*8 + fi*2+1] = val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 3];
                           }
                        }
                        evalGate(gTypeDum_d[gateId],fival_s[threadIdx.x*8 + 0],fival_s[threadIdx.x*8 + 1],fival_s[threadIdx.x*8 + 2],fival_s[threadIdx.x*8 + 3],
                                 fival_s[threadIdx.x*8 + 4],fival_s[threadIdx.x*8 + 5],fival_s[threadIdx.x*8 + 6],fival_s[threadIdx.x*8 + 7],
                                 &twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2]);
                        unsigned int foStr = foOffsetDum_d[gateId];
                        unsigned int foEnd = foOffsetDum_d[gateId+1];
                        if(foEnd - foStr != 0){
                            if((twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 0] !=
                                val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 2] ||
                                twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 1] !=
                                val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 3])){
                                // fault can propogate =>  set foGate effected pin
                                for(int fo = foStr ; fo < foEnd; ++fo){
                                    atomicAdd(&twoLvlfG_d[foArrayDum_d[fo]-gStrNextLvl],(0x01<<foIdxArrayDum_d[fo]));
                                }
                            }
                        }
                        // evaluate AT after every blockDim.x faulty gates have been evaluated
                        for(int k = 0 ; k < detPatNum_s[0]; ++k){
                            char patIdx = dict_s[k];
                            if(patDone_s[patIdx]){ // this pattern has met DSM criteria
                                continue;
                            }
                            char outV = getV(twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 0],twoLvlval_d[dataflag*gatesPerLvl*2 + (gateId-gStrCurrLvl)*2 + 1],
                                             val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 2],val_d[tex1Dfetch(gDum2Ori_t,gateId)*4 + 3],patIdx);// faulty value
                            if(outV < 2){  // D' = STF or D = STR faulty value can propogate
                                unsigned int fiNum = getFiNum(gTypeDum_d[gateId]);
                                float PDa;  // actual path delay
                                bool isCtrl = getCtrl(gTypeDum_d[gateId],outV);
                                char trType = transType(gTypeDum_d[gateId],outV); // 0 = fin D ; 1 = D' ; 2 = fin any transition
                                int transPin = -1;
                                // isCtrl is the same as previous
                                // ex: when AND gate output is D(STR) we want to find the latest D(STR) on it output
                                // => isCtrl = false (find latest input D) trType = D(0)
                                // trType is the input transition type we looking for
                                if(isCtrl){ // output  control value
                                    PDa = 1000.0;
                                    for(char fi = 0 ; fi < fiNum ; ++fi){
                                        unsigned int figateId = gFiDum_d[gateId*4 + fi]; // gateId start from 0
                                        float delay = gTypeDum_d[gateId] == 33 ? 0.0 : dList_d[tex1Dfetch(gDum2Ori_t,gateId)*4*2 + fi*2 + outV];
                                        char fitr;
                                        if((fPin&(0x01<<fi)) != 0){
                                            fitr = getV(twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 0],twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 1],
                                                    val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 2],val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 3],patIdx);
                                            if((trType == fitr || trType == 2) && PDa >=
                                                twoLvlat_d[(!dataflag)*gatesPerLvl*paraPatNum + (figateId-gStrPrevLvl)*paraPatNum + patIdx] + delay){
                                                PDa = twoLvlat_d[(!dataflag)*gatesPerLvl*paraPatNum + (figateId-gStrPrevLvl)*paraPatNum + patIdx] + delay;
                                                transPin = fi;
                                            }
                                        }
                                    }
                                }
                                else{
                                    PDa = -1000.0;
                                    for(char fi = 0 ; fi < fiNum ; ++fi){
                                        unsigned int figateId = gFiDum_d[gateId*4 + fi]; // gateId start from 0
                                        float delay = gTypeDum_d[gateId] == 33 ? 0.0 : dList_d[tex1Dfetch(gDum2Ori_t,gateId)*4*2 + fi*2 + outV] ;
                                        char fitr;
                                        if((fPin&(0x01<<fi)) != 0){
                                            fitr = getV(twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 0],twoLvlval_d[(!dataflag)*gatesPerLvl*2 + (figateId-gStrPrevLvl)*2 + 1],
                                                    val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 2],val_d[tex1Dfetch(gDum2Ori_t,figateId)*4 + 3],patIdx);
                                            if((trType == fitr || trType == 2) && PDa <=
                                                twoLvlat_d[(!dataflag)*gatesPerLvl*paraPatNum + (figateId-gStrPrevLvl)*paraPatNum + patIdx] + delay){
                                                PDa = twoLvlat_d[(!dataflag)*gatesPerLvl*paraPatNum + (figateId - gStrPrevLvl)*paraPatNum + patIdx] + delay;
                                                transPin = fi;
                                            }
                                        }
                                    }
                                }
                                twoLvlat_d[(dataflag)*gatesPerLvl*paraPatNum + (gateId-gStrCurrLvl)*paraPatNum + patIdx] = PDa;
                                if(gTypeDum_d[gateId] == 1 || gTypeDum_d[gateId] == 3){ // PO or PPO, check DSM (Use Atual path delay)
                                    if((PDs_s[0] - PDa)/(Ttc - PDa) < delta){
                                        partialDict_d[fId*paraPatNum + patIdx] = 2;
                                        patDone_s[patIdx] = true;
                                    }
                                }
                            }
                        }
                    }
                }
                __syncthreads();
                // add event List
                if(currlvl+1 < cirLvl){
                    // evaluate a set of gates
                    loop = (eventSize_s[0] - 1)/blockDim.x + 1;
                    unsigned int eventSize = 0;
                    for(int j = 0 ; j < loop; ++j){
                        __syncthreads();
                        unsigned int Idx = j*blockDim.x + threadIdx.x;
                        if(Idx < eventSize_s[0]){
                            unsigned int eventGate = EventList_d[(!dataflag)*gatesPerLvl + Idx]>>4;
                            foStr_s[threadIdx.x]  = foOffsetDum_d[eventGate];
                            foSize_s[threadIdx.x] = foOffsetDum_d[eventGate+1] - foOffsetDum_d[eventGate];
                        }
                        __syncthreads();
                        if(threadIdx.x == 0){
                            for(int m = 0 ; m < blockDim.x && j*blockDim.x + m < eventSize_s[0]; ++m){
                                for(int fo = 0; fo < foSize_s[m]; ++fo){
                                    if((twoLvlfG_d[foArrayDum_d[foStr_s[m]+fo]-gStrNextLvl]) != 0){
                                        EventList_d[dataflag*gatesPerLvl + eventSize] = (foArrayDum_d[foStr_s[m]+fo]<<4) + (twoLvlfG_d[foArrayDum_d[foStr_s[m]+fo]-gStrNextLvl]);
                                        twoLvlfG_d[foArrayDum_d[foStr_s[m]+fo]-gStrNextLvl] = 0;
                                        eventSize++;
                                    }
                                }
                            }
                        }
                        __syncthreads();
                    }
                    if(threadIdx.x == 0){
                        eventSize_s[0] = eventSize;
                    }
                }
            }
        }
    }

}
//}}}
//{{{ __global__ void SFDAnalysis()
__global__ void SFDAnalysis(char* partialDict_d,int* SFD_d,int* SFD_z,unsigned int* fMask_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,
                            bool* pRdn_d,unsigned int RmnpNum,int patLoop,int iterNum,int mode){
    unsigned int RmnfNum = RmnfNum_d[0];
    int loop;
    unsigned fId;
    if(iterNum == 0){ // Iteration
        if(mode == 0){  // mode 0: after PDLB analysis
            loop = (RmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop; ++i){
                // no coleasing read
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < RmnfNum){
                    fId = Rmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                    bool meetCond = false;  // to see if meet two condition
                    for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                        if(partialDict_d[fId*paraPatNum + (j -patLoop*paraPatNum)] != 0){  // dict == 1 or 2
                            meetCond = true;
                            break;
                        }
                    }
                    if(patLoop == 0){
                        SFD_d[fId] = -4;
                    }
                    if(meetCond){
                        fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = fId;
                    }
                    else{
                        fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = ~0;
                    }
                }

            }
        }
        else if(mode == 1){
            loop = (RmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop ; ++i){
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < RmnfNum){
                    fId = Rmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                    int SFD = SFD_d[fId];
                    bool detect = false;  // to see if fault is detected int this pattern Loop
                    for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                        unsigned int patIdx = j-patLoop*paraPatNum;
                        if(partialDict_d[fId*paraPatNum + patIdx] == 1){
                            SFD |= 0x01;
                        }
                        else if(partialDict_d[fId*paraPatNum + patIdx] == 2){
                            detect = true;
                            if(SFD == -4){
                                SFD = (patIdx<<2);
                            }
                            else if((SFD>>2) >= 0){     // have already detect once
                                SFD = 2;
                                break;
                            }
                            else{
                                SFD = (patIdx<<2) | (SFD&0x01);
                            }
                        }
                    }
                    // extract remain fault with Q
                    if((SFD&0x01) == 1){
                        fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = fId;
                    }
                    else{
                        fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = ~0;
                        if(detect){
                            SFD_z[fId] = SFD | 0x01;
                        }
                        else{
                            SFD_z[fId] = SFD&((~0)<<1);
                        }
                    }
                    SFD_d[fId] = SFD&((~0)<<1);
                }
            }
        }
        else if(mode == 2){
            __shared__ bool pRdn_s[paraPatNum];
            loop = (paraPatNum - 1) / (SFD_thNum) + 1;
            for(int i = 0 ; i < loop; ++i){
                if(i*SFD_thNum +  threadIdx.x < paraPatNum){
                    pRdn_s[i*SFD_thNum +  threadIdx.x] = pRdn_d[i*SFD_thNum +  threadIdx.x];
                }
            }
            __syncthreads();
            loop = (RmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop ; ++i){
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < RmnfNum){
                    fId = Rmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                    int SFD = SFD_d[fId] & ((~0)<<1);
                    bool detect = false;
                    for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                        unsigned int patIdx = j-patLoop*paraPatNum;
                        if(partialDict_d[fId*paraPatNum + patIdx] == 2){
                            detect = true;
                            if((SFD>>2) >= 0){
                                SFD = 2;
                                break;
                            }
                            else if((SFD>>2) < 0){
                                SFD = (patIdx<<2);
                            }
                        }
                    }
                    SFD_d[fId] = SFD;
                    if(detect)
                        SFD_z[fId] = SFD | 0x01;
                    else
                        SFD_z[fId] = SFD;
                }
            }
        }
    }
    else{
        if(mode == 0){
            loop = (paraPatNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop; ++i){
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < paraPatNum){
                    pRdn_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = true;
                }
            }
            loop = (RmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop; ++i){
                // no coleasing read
                // Initialize pRdn
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < RmnfNum){
                    fId = Rmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                    bool meetCond = false;  // to see if meet two condition
                    for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                        if(partialDict_d[fId*paraPatNum + (j -patLoop*paraPatNum)] != 0){  // dict == 1 or 2
                            meetCond = true;
                            break;
                        }
                    }
                    if(patLoop == 0){
                        SFD_d[fId] = -4;
                    }
                    if(meetCond){
                        fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = fId;
                    }
                    else{
                        fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = ~0;
                    }
                }

            }
        }
        else if(mode == 1){
            loop = (RmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop ; ++i){
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < RmnfNum){
                    fId = Rmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                    int SFD = SFD_d[fId];
                    for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                        unsigned int patIdx = j-patLoop*paraPatNum;
                        if(partialDict_d[fId*paraPatNum + patIdx] == 1 ){
                            if((SFD>>2) < 0){
                                pRdn_d[patIdx] = false;
                            }
                        }
                        if(partialDict_d[fId*paraPatNum + patIdx] == 2){
                            if((SFD>>2) < 0){
                                pRdn_d[patIdx] = false;
                            }
                            break;
                        }
                    }
                }
            }
        }
        else if(mode == 2){
            loop = (paraPatNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop; ++i){
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < paraPatNum){
                    pRdn_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = true;
                }
            }
            loop = (RmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
            for(int i = 0 ; i < loop ; ++i){
                if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < RmnfNum){
                    fId = Rmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                    int SFD = SFD_d[fId];
                    for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                        unsigned int patIdx = j-patLoop*paraPatNum;
                        if(partialDict_d[fId*paraPatNum + patIdx] == 2){
                            if((SFD>>2) < 0){
                                pRdn_d[patIdx] = false;
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}
//}}}
//{{{ __global__ void SFDRdnPatBuild()
__global__ void SFDRdnPatBuild(char* partialDict_d,int* SFD_d,int* SFD_z,unsigned int* LBRmnfault_d,unsigned int* LBRmnfNum_d,
                                    bool* pRdn_d,unsigned int RmnpNum,unsigned int* fMask_d,int patLoop,int mode){
    __shared__ bool pRdn_s[paraPatNum];
    int loop = (paraPatNum - 1) / (SFD_thNum) + 1;
    for(int i = 0 ; i < loop; ++i){
        if(i*SFD_thNum + threadIdx.x < paraPatNum)
            pRdn_s[i*SFD_thNum + threadIdx.x] = pRdn_d[i*SFD_thNum + threadIdx.x];
    }
    unsigned int LBRmnfNum = LBRmnfNum_d[0];
    unsigned fId;
    __syncthreads();
    if(mode == 1){
        loop = (LBRmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
        for(int i = 0 ; i < loop ; ++i){
            if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < LBRmnfNum){
                fId = LBRmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                int SFD = SFD_d[fId];
                for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                    unsigned int patIdx = j-patLoop*paraPatNum;
                    if(!pRdn_s[patIdx]){
                        if(partialDict_d[fId*paraPatNum + patIdx] == 1){
                            SFD |= 0x01;
                        }
                        else if(partialDict_d[fId*paraPatNum + patIdx] == 2){
                            if(SFD == -4){
                                SFD = (patIdx<<2);
                            }
                            else if((SFD>>2) >= 0){     // have already detect once
                                SFD = 2 | (SFD&0x01);
                                break;
                            }
                            else{
                                SFD = (patIdx<<2) | (SFD&0x01);
                            }
                        }
                    }
                }
                // extract remain fault with Q
                if((SFD&0x01) == 1){
                    fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = fId;
                }
                else{
                    fMask_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x] = ~0;
                }
            }
        }
    }
    else{
        loop = (LBRmnfNum - 1) / (SFD_thNum*SFD_bkNum) + 1;
        for(int i = 0 ; i < loop ; ++i){
            if(i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x < LBRmnfNum){
                fId = LBRmnfault_d[i*SFD_thNum*SFD_bkNum + blockIdx.x*SFD_thNum + threadIdx.x];
                int SFD = SFD_d[fId];
                bool detect = false;
                for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < RmnpNum; ++j){
                    unsigned int patIdx = j-patLoop*paraPatNum;
                    //if(fId == 0){
                    //    printf("fId:%d patIdx:%d partialDict_d:%d SFD:%d\n",fId,patIdx,partialDict_d[fId*paraPatNum + j],SFD);
                    //}
                    if(!pRdn_s[patIdx]){ // pattern is not redundant
                        if(partialDict_d[fId*paraPatNum + patIdx] == 2){
                            detect = true;
                            if(SFD == -4){
                                SFD = (patIdx<<2);
                            }
                            else if((SFD>>2) >= 0){
                                SFD = 2;
                                break;
                            }
                            else{
                                SFD = (patIdx<<2);
                            }
                        }
                    }
                }
                SFD_d[fId] = SFD;
                if(detect)
                    SFD_z[fId] = SFD | 0x01;
                else
                    SFD_z[fId] = SFD & ((~0)<<1);
            }
        }
    }
}
//}}}
//{{{ __device__ bool isInv()
__device__ bool isInv(unsigned int gType){
    if((gType >= 10 && gType <= 13) ||
       (gType >= 18 && gType <= 21) ||
       (gType >= 25 && gType <= 27) ||
       (gType == 29 )){
        return true;
    }
    return false;
}
//}}}
//{{{ __device__ char getTrans()
__device__ char getTrans(PatValue t0_l_,PatValue t0_h_,PatValue t1_l_,PatValue t1_h_,int bitIdx){
    PatValue mask = 0x01;
    char t0,t1;

    char v0 = (t0_l_ & (mask<<bitIdx)) == 0 ? 0 : 1;
    char v1 = (t0_h_ & (mask<<bitIdx)) == 0 ? 0 : 1;
    if(v0 == 0 && v1 == 1){
        t0 = 1;
    }
    else if(v0 == 1 && v1 == 0){
        t0 = 0;
    }
    else if(v0 == 0 && v1 == 0){
        t0 = 2; // 2 = X
    }
    else{
        return 2;
    }

    v0 = (t1_l_ & (mask<<bitIdx)) == 0 ? 0 : 1;
    v1 = (t1_h_ & (mask<<bitIdx)) == 0 ? 0 : 1;
    if(v0 == 0 && v1 == 1){
        t1 = 1;
    }
    else if(v0 == 1 && v1 == 0){
        t1 = 0;
    }
    else if(v0 == 0 && v1 == 0){
        t1 = 2; // 2 = X
    }
    else{
        return 2;
    }

    if(t0 != t1){
        if(t0 == 0)
            return 0;   // rising
        if(t0 == 1)
            return 1;   // falling
    }
    else{
        return 2;
    }
    return 2;
}
//}}}
//{{{ __device__ char getFiNum()
__device__ char  getFiNum(unsigned int gType){
    char fiNum;
    switch(gType){
        case  0: fiNum = 0; break;
        case  1: fiNum = 1; break;
        case  2: fiNum = 1; break;
        case  3: fiNum = 1; break;
        case  4: fiNum = 0; break;
        case  5: fiNum = 0; break;
        case  6: fiNum = 0; break;
        case  7: fiNum = 2; break;
        case  8: fiNum = 3; break;
        case  9: fiNum = 4; break;
        case 10: fiNum = 0; break;
        case 11: fiNum = 2; break;
        case 12: fiNum = 3; break;
        case 13: fiNum = 4; break;
        case 14: fiNum = 0; break;
        case 15: fiNum = 2; break;
        case 16: fiNum = 3; break;
        case 17: fiNum = 4; break;
        case 18: fiNum = 0; break;
        case 19: fiNum = 2; break;
        case 20: fiNum = 3; break;
        case 21: fiNum = 4; break;
        case 22: fiNum = 0; break;
        case 23: fiNum = 2; break;
        case 24: fiNum = 3; break;
        case 25: fiNum = 0; break;
        case 26: fiNum = 2; break;
        case 27: fiNum = 3; break;
        case 28: fiNum = 1; break;
        case 29: fiNum = 1; break;
        case 30: fiNum = 0; break;
        case 31: fiNum = 0; break;
        case 32: fiNum = 0; break;
        case 33: fiNum = 1; break;
        default:
                 fiNum =0;
    }
    return fiNum;
}
//}}}

//{{{ __device__ bool getCtrl()
__device__ bool getCtrl(unsigned int gType, char trans){
    // Given gate type and gate output transition
    // Return we need to find the controlling value or noncontrolling value in fanin of the gate
    bool isCtrl = false;
    switch(gType){
        case  0: isCtrl = false; break; // PI
        case  1: isCtrl = false; break; // PO
        case  2: isCtrl = false; break; // PPI
        case  3: isCtrl = false; break; // PPO
        case  4: isCtrl = false; break; // TIEHI
        case  5: isCtrl = false; break; // TIELO
        case  6: // AND
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  7: // AND2
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  8:
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  9:
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  10: // NAND
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  11:
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  12:
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  13:
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  14: // OR
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  15:
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  16:
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  17:
                 if(trans == 0){
                     isCtrl = true;
                 }
                 else{
                     isCtrl = false;
                 }
                 break;
        case  18: // NOR
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  19:
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  20:
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case  21:
                 if(trans == 0){
                     isCtrl = false;
                 }
                 else{
                     isCtrl = true;
                 }
                 break;
        case 22: isCtrl = false; break; // XOR
        case 23: isCtrl = false; break;
        case 24: isCtrl = false; break;
        case 25: isCtrl = false; break; // XNOR
        case 26: isCtrl = false; break;
        case 27: isCtrl = false; break;
        case 28: isCtrl = false; break; // BUF
        case 29: isCtrl = false; break; // INV
        case 30: isCtrl = false; break;
        case 31: isCtrl = false; break;
        case 32: isCtrl = false; break;
        case 33: isCtrl = false; break; // DUMMY
    }
    return isCtrl;
}
//}}}
//{{{ __device__ char transType()
__device__ char transType(unsigned int gType, char trans){  // 0 =  fin rising ; 1 = fin falling ; 2 = fin any transition
    // Given gate type and gate output transition
    // Find the transition we need to find in fanin of the gate
    char trType = 0;
    switch(gType){
        case  0: trType = 2;break; // PI
        case  1: trType = 2;break; // PO
        case  2: trType = 2;break; // PPI
        case  3: trType = 2;break; // PPO
        case  4: trType = 2;break; // TIEHI
        case  5: trType = 2;break; // TIELO
        case  6: // AND
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  7: // AND2
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  8:
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  9:
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  10: // NAND
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  11:
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  12:
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  13:
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  14: // OR
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  15:
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  16:
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  17:
                 if(trans == 0){
                     trType = 0;
                 }
                 else{
                     trType = 1;
                 }
                 break;
        case  18: // NOR
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  19:
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  20:
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case  21:
                 if(trans == 0){
                     trType = 1;
                 }
                 else{
                     trType = 0;
                 }
                 break;
        case 22: trType = 2;  break; // XOR
        case 23: trType = 2;  break;
        case 24: trType = 2;  break;
        case 25: trType = 2;  break; // XNOR
        case 26: trType = 2;  break;
        case 27: trType = 2;  break;
        case 28: trType = 2;  break; // BUF
        case 29: trType = 2;  break; // INV
        case 30: trType = 2;  break;
        case 31: trType = 2;  break;
        case 32: trType = 2;  break;
        case 33: trType = 2;  break; // DUMMY
    }
    return trType;
}
//}}}
//{{{ __device__ char getBitValue()
__device__ char getBV(PatValue pv,int bitIdx){
    return (pv & ((PatValue)0x01 << bitIdx)) == 0 ? 0 : 1;
}
//}}}
//{{{ __device__ void getV()
__device__ char getV(PatValue fl_,PatValue fh_,PatValue gl_, PatValue gh_,unsigned int bitIdx){
    // Given gate fauly low/high value, faulty free low/high value and bit index
    // Return this pattern is D/D' or faulty free
    PatValue mask = 0x01;
    char fv,gv;   // fault value good value
    char vl = (fl_ &(mask<<bitIdx)) == 0 ? 0 : 1;
    char vh = (fh_ &(mask<<bitIdx)) == 0 ? 0 : 1;
    if(vl == 0 && vh == 1)
        fv = 1;
    else if(vl == 1 && vh == 0)
        fv = 0;
    else if(vl == 0 && vh ==0)
        fv = 2; // X
    else
        fv =3;  // dont care
    vl = (gl_ &(mask<<bitIdx)) == 0 ? 0 : 1;
    vh = (gh_ &(mask<<bitIdx)) == 0 ? 0 : 1;
    if(vl == 0 && vh == 1)
        gv = 1;
    else if(vl == 1 && vh == 0)
        gv = 0;
    else if(vl == 0 && vh ==0)
        gv = 2; // X
    else
        gv = 3;  // dont care
    if(gv == 0 && fv == 1)
        return 1;   // D' = good0/faulty1 is equal to falling
    else if(gv == 1 && fv == 0)
        return 0;   // D = good1/faulty0 is equal to rising
    else if(gv == 2 && fv == 1)
        return 1;   // D'
    else if(gv == 2 && fv == 0)
        return 0;   // D
    else if(gv == fv)
        return 2;   // faulty free
    else
        return 3;
}
//}}}
//{{{ __device__ void evalGate()
__device__ void evalGate(unsigned int gateId,unsigned int gType,unsigned int gFiOri0,unsigned int gFiOri1,unsigned int gFiOri2,unsigned int gFiOri3,
                         PatValue* val_d,PatValue hold_capture,int timeframe){
    // Evaluate function for logicSim. Evaluate the faulty free value of the gate
    // The faulty free value will be written back to val_d
    if(gType ==0){
        return;
    }
    else if(gType == 2){ // PPI
        // hold_capture indicate that which patterns will capture in time frame 1 in m patterns
        // modBit Indicate that which bit should be changed from time frame 0 to time frame 1
        // modified l_ of PPI
        PatValue modBit = (val_d[gFiOri0*4 + 2*(timeframe-1) + 0] ^ val_d[gateId*4 + 2*(timeframe-1) + 0]) & hold_capture;
        val_d[gateId*4 + 2*timeframe + 0] = val_d[gateId*4 + 2*(timeframe-1) + 0] ^ modBit;
        // modified h_ of PPI
        modBit = (val_d[gFiOri0*4 + 2*(timeframe-1) + 1] ^ val_d[gateId*4 + 2*(timeframe-1) + 1]) & hold_capture;
        val_d[gateId*4 + 2*timeframe + 1] = val_d[gateId*4 + 2*(timeframe-1) + 1] ^ modBit;
    }
    if(gType == 1 || gType == 3 || gType == 28){
        val_d[gateId*4 + 2*timeframe + 0] = val_d[gFiOri0*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] = val_d[gFiOri0*4 + 2*timeframe + 1];
    }
    else if(gType == 4){
        val_d[gateId*4 + 2*timeframe + 0] = 0;
        val_d[gateId*4 + 2*timeframe + 1] = ~0;
    }
    else if(gType == 5){
        val_d[gateId*4 + 2*timeframe + 0] = ~0;
        val_d[gateId*4 + 2*timeframe + 1] = 0;
    }
    else if(gType == 6){ // AND
    }
    else if(gType == 7){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 0] | val_d[gFiOri1*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1];
    }
    else if(gType == 8){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 0] | val_d[gFiOri1*4 + 2*timeframe + 0] | val_d[gFiOri2*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 1];
    }
    else if(gType == 9){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 0] | val_d[gFiOri1*4 + 2*timeframe + 0] | val_d[gFiOri2*4 + 2*timeframe + 0] | val_d[gFiOri3*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 1] & val_d[gFiOri3*4 + 2*timeframe + 1];
    }
    else if(gType == 10){ // NAND
    }
    else if(gType == 11){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 0] | val_d[gFiOri1*4 + 2*timeframe + 0];
    }
    else if(gType == 12){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 0] | val_d[gFiOri1*4 + 2*timeframe + 0] | val_d[gFiOri2*4 + 2*timeframe + 0];
    }
    else if(gType == 13){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 1] & val_d[gFiOri3*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 0] | val_d[gFiOri1*4 + 2*timeframe + 0] | val_d[gFiOri2*4 + 2*timeframe + 0] | val_d[gFiOri3*4 + 2*timeframe + 0];
    }
    else if(gType == 14){ // OR
    }
    else if(gType == 15){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 1] | val_d[gFiOri1*4 + 2*timeframe + 1];
    }
    else if(gType == 16){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 1] | val_d[gFiOri1*4 + 2*timeframe + 1] | val_d[gFiOri2*4 + 2*timeframe + 1];
    }
    else if(gType == 17){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 0] & val_d[gFiOri3*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 1] | val_d[gFiOri1*4 + 2*timeframe + 1] | val_d[gFiOri2*4 + 2*timeframe + 1] | val_d[gFiOri3*4 + 2*timeframe + 1];
    }
    else if(gType == 18){ // NOR
    }
    else if(gType == 19){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 1] | val_d[gFiOri1*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0];
    }
    else if(gType == 20){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 1] | val_d[gFiOri1*4 + 2*timeframe + 1] | val_d[gFiOri2*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 0];
    }
    else if(gType == 21){
        val_d[gateId*4 + 2*timeframe + 0] =  val_d[gFiOri0*4 + 2*timeframe + 1] | val_d[gFiOri1*4 + 2*timeframe + 1] | val_d[gFiOri2*4 + 2*timeframe + 1] | val_d[gFiOri3*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] =  val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 0] & val_d[gFiOri3*4 + 2*timeframe + 0];
    }
    else if(gType == 22){ // XOR
    }
    else if(gType == 23){
        val_d[gateId*4 + 2*timeframe + 0] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1]);
        val_d[gateId*4 + 2*timeframe + 1] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 1]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 0]);
    }
    else if(gType == 24){
        val_d[gateId*4 + 2*timeframe + 0] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1]);
        val_d[gateId*4 + 2*timeframe + 1] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 1]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 0]);
        val_d[gateId*4 + 2*timeframe + 0] = (val_d[gateId*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 0]) | (val_d[gateId*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 1]);
        val_d[gateId*4 + 2*timeframe + 1] = (val_d[gateId*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 1]) | (val_d[gateId*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 0]);
    }
    else if(gType == 25){ // XNOR
    }
    else if(gType == 26){
        val_d[gateId*4 + 2*timeframe + 0] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 1]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 0]);
        val_d[gateId*4 + 2*timeframe + 1] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1]);
    }
    else if(gType == 27){
        val_d[gateId*4 + 2*timeframe + 0] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 0]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 1]);
        val_d[gateId*4 + 2*timeframe + 1] = (val_d[gFiOri0*4 + 2*timeframe + 0] & val_d[gFiOri1*4 + 2*timeframe + 1]) | (val_d[gFiOri0*4 + 2*timeframe + 1] & val_d[gFiOri1*4 + 2*timeframe + 0]);
        val_d[gateId*4 + 2*timeframe + 0] = (val_d[gateId*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 0]) | (val_d[gateId*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 1]);
        val_d[gateId*4 + 2*timeframe + 1] = (val_d[gateId*4 + 2*timeframe + 0] & val_d[gFiOri2*4 + 2*timeframe + 1]) | (val_d[gateId*4 + 2*timeframe + 1] & val_d[gFiOri2*4 + 2*timeframe + 0]);
        PatValue temp = val_d[gateId*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 0] = val_d[gFiOri0*4 + 2*timeframe + 0];
        val_d[gateId*4 + 2*timeframe + 1] = temp;
    }
    else if(gType == 29){
        val_d[gateId*4 + 2*timeframe + 0] = val_d[gFiOri0*4 + 2*timeframe + 1];
        val_d[gateId*4 + 2*timeframe + 1] = val_d[gFiOri0*4 + 2*timeframe + 0];
    }
    else if(gType == 30){
    }

}
__device__ void evalGate(unsigned int gType,PatValue fi0l_,PatValue fi0h_,PatValue fi1l_,PatValue fi1h_,
        PatValue fi2l_,PatValue fi2h_,PatValue fi3l_,PatValue fi3h_,PatValue* twoLvlval_d){
    // Evaluate function for faultSim. Evaluate the faulty value of the gate
    // The faulty value will be written back to twoLvlval_d
    if(gType == 0){
        return;
    }
    else if(gType == 1){
        twoLvlval_d[0] = fi0l_;
        twoLvlval_d[1] = fi0h_;
    }
    else if(gType == 3){
        twoLvlval_d[0] = fi0l_;
        twoLvlval_d[1] = fi0h_;
    }
    else if(gType == 2){
        twoLvlval_d[0] = fi0l_;
        twoLvlval_d[1] = fi0h_;
    }
    else if(gType == 28){
        twoLvlval_d[0] = fi0l_;
        twoLvlval_d[1] = fi0h_;
    }
    else if(gType == 33){
        twoLvlval_d[0] = fi0l_;
        twoLvlval_d[1] = fi0h_;
    }
    else if(gType == 29){ // INV
        twoLvlval_d[0] = fi0h_;
        twoLvlval_d[1] = fi0l_;
    }
    else if(gType == 4){
        twoLvlval_d[0] = 0;
        twoLvlval_d[1] = ~0;
    }
    else if(gType == 5){
        twoLvlval_d[0] = ~0;
        twoLvlval_d[1] = 0;
    }
    else if(gType == 6){ // AND
    }
    else if(gType == 7){
        twoLvlval_d[0] =  fi0l_ | fi1l_;
        twoLvlval_d[1] =  fi0h_ & fi1h_;
    }
    else if(gType == 8){
        twoLvlval_d[0] = fi0l_ | fi1l_ | fi2l_;
        twoLvlval_d[1] = fi0h_ & fi1h_ & fi2h_;
    }
    else if(gType == 9){
        twoLvlval_d[0] = fi0l_ | fi1l_ | fi2l_ | fi3l_;
        twoLvlval_d[1] = fi0h_ & fi1h_ & fi2h_ & fi3h_;
    }
    else if(gType == 10){ // NAND
    }
    else if(gType == 11){
        twoLvlval_d[0] =  fi0h_ & fi1h_;
        twoLvlval_d[1] =  fi0l_ | fi1l_;
    }
    else if(gType == 12){
        twoLvlval_d[0] =  fi0h_ & fi1h_ & fi2h_;
        twoLvlval_d[1] =  fi0l_ | fi1l_ | fi2l_;
    }
    else if(gType == 13){
        twoLvlval_d[0] =  fi0h_ & fi1h_ & fi2h_ & fi3h_;
        twoLvlval_d[1] =  fi0l_ | fi1l_ | fi2l_ | fi3l_;
    }
    else if(gType == 14){ // OR
    }
    else if(gType == 15){
        twoLvlval_d[0] =  fi0l_ & fi1l_;
        twoLvlval_d[1] =  fi0h_ | fi1h_;
    }
    else if(gType == 16){
        twoLvlval_d[0] =  fi0l_ & fi1l_ & fi2l_;
        twoLvlval_d[1] =  fi0h_ | fi1h_ | fi2h_;
    }
    else if(gType == 17){
        twoLvlval_d[0] =  fi0l_ & fi1l_ & fi2l_ & fi3l_;
        twoLvlval_d[1] =  fi0h_ | fi1h_ | fi2h_ | fi3h_;
    }
    else if(gType == 18){ // NOR
    }
    else if(gType == 19){
        twoLvlval_d[0] =  fi0h_ | fi1h_;
        twoLvlval_d[1] =  fi0l_ & fi1l_;
    }
    else if(gType == 20){
        twoLvlval_d[0] =  fi0h_ | fi1h_ | fi2h_;
        twoLvlval_d[1] =  fi0l_ & fi1l_ & fi2l_;
    }
    else if(gType == 21){
        twoLvlval_d[0] =  fi0h_ | fi1h_ | fi2h_ | fi3h_;
        twoLvlval_d[1] =  fi0l_ & fi1l_ & fi2l_ & fi3l_;
    }
    else if(gType == 22){ // XOR
    }
    else if(gType == 23){
        twoLvlval_d[0] = (fi0l_ & fi1l_)| (fi0h_ & fi1h_);
        twoLvlval_d[1] = (fi0l_ & fi1h_)| (fi0h_ & fi1l_);
    }
    else if(gType == 24){
        twoLvlval_d[0] = ((fi0l_ & fi1l_)| (fi0h_ & fi1h_) & fi2l_) | ((fi0l_ & fi1h_)| (fi0h_ & fi1l_) & fi2h_);
        twoLvlval_d[1] = ((fi0l_ & fi1l_)| (fi0h_ & fi1h_) & fi2h_) | ((fi0l_ & fi1h_)| (fi0h_ & fi1l_) & fi2l_);
    }
    else if(gType == 25){ // XNOR
    }
    else if(gType == 26){
        twoLvlval_d[0] = (fi0l_ & fi1h_)| (fi0h_ & fi1l_);
        twoLvlval_d[1] = (fi0l_ & fi1l_)| (fi0h_ & fi1h_);
    }
    else if(gType == 27){
        twoLvlval_d[0] = ((fi0l_ & fi1l_)| (fi0h_ & fi1h_) & fi2h_) | ((fi0l_ & fi1h_)| (fi0h_ & fi1l_) & fi2l_);
        twoLvlval_d[1] = ((fi0l_ & fi1l_)| (fi0h_ & fi1h_) & fi2l_) | ((fi0l_ & fi1h_)| (fi0h_ & fi1l_) & fi2h_);
    }
    else if(gType == 30){
    }
}
//}}}
//{{{ void SddCudaSim::CompactRedundantFault()
void SddCudaSim::CompactRedundantFault(int* SFD,bool* fRdn_d,vector<unsigned int>& faultList,unsigned int iterNum,unsigned int& DSMfNum){
    // Iteration 0 identify U fault which are not detect by DSM
    // Iteration 1 identify fault which arre not detect by TFS & DSM
    if(iterNum == 0){
        ofstream udf;
        if(arg->DSM_only == true)
            udf.open(arg->UDfName.c_str());
        // after iterNum 0 identify Redundant fault
        // these faults don't have to use UB/LB in next iteration
        bool*   fRdn = (bool*)malloc(sizeof(bool)*faultList.size());
        for(int i = 0 ; i < faultList.size(); ++i){
            if((SFD[i]>>2) < 0){ // redundant fault
                fRdn[i] = true;
                if(arg->DSM_only){
                    udf<<i<<endl;
                }
            }
            else{
                fRdn[i] = false;
                DSMfNum++;
            }
        }
        cudaMemcpy(fRdn_d,fRdn,sizeof(bool)*faultList.size(),cudaMemcpyHostToDevice);
        free(fRdn);
        if(arg->DSM_only)
            udf.close();
    }
    else if(iterNum == 1){
        // after iterNum 1 if fault still redundant
        // these fault can't be detect by both TRF and timing
        // remove these pattern from remain fault list
        vector<unsigned int> faultList_tmp = faultList;
        faultList.clear();
        for(int i = 0 ; i < faultList_tmp.size(); ++i){
            if((SFD[i]>>2) >= 0){ // not redundant fault
                faultList.push_back(i);
            }
        }
    }

}
//}}}
//{{{ void SddCudaSim::SetRedundantPat()
void SddCudaSim::SetRedundantPat(bool* pRdn_d,vector<Pat*>& patList,int patLoop){
    cudaThreadSynchronize();
    bool* pRdn = (bool*)malloc(sizeof(bool)*paraPatNum);
    cudaMemcpy(pRdn,pRdn_d,sizeof(bool)*paraPatNum ,cudaMemcpyDeviceToHost);
    for(unsigned int i = patLoop*paraPatNum; i < (patLoop+1)*paraPatNum && i < patList.size(); ++i){
        unsigned int patIdx = i - patLoop*paraPatNum;
        if(pRdn[patIdx]){ //redundant pattern
            patList[i]->redundant = true;
            //printf("X");
        }
        else{
            //printf("O");
        }
    }
    free(pRdn);
}
//}}}
//{{{ void Check Function()
void SddCudaSim::CheckLogicVal(PatValue* val_d,int patLoop,int patNum, CircuitInfo* cirInfo){
    PatValue* val = (PatValue*)malloc(sizeof(PatValue)*(cirInfo->OrigateNum)*4*LS_bkNum);
    cudaMemcpy(val        ,val_d       ,sizeof(PatValue)*(cirInfo->OrigateNum)*4*LS_bkNum   ,cudaMemcpyDeviceToHost);
    for(int m = 0 ; m < LS_bkNum && patLoop+m < (patNum-1)/paraPatNum + 1; ++m){
        cout<<"********* Pattern: "<<m<<" *********"<<endl;
        int offset = cirInfo->OrigateNum*4*m;
        for(int j = 0 ; j < cirInfo->OrigateNum;++j){
            printf("gate %8d_t0:",j);PrintBinaryValue(val[offset + 4*j+0],val[offset + 4*j+1]);
            printf("gate %8d_t1:",j);PrintBinaryValue(val[offset + 4*j+2],val[offset + 4*j+3]);
            cout<<"------------------------------------------------------"<<endl;
        }
    }
    free(val);
}
void SddCudaSim::CheckDict(char* dictCPU,char* partialDict_d,vector<unsigned int>& RmnfaultList,int patLoop,int patNum, CircuitInfo* cirInfo){
    char*   dictGPU         = (char*)malloc(sizeof(char)*cirInfo->fNum*paraPatNum);
    cudaMemcpy(dictGPU          ,partialDict_d       ,sizeof(char)*(cirInfo->fNum)*paraPatNum ,cudaMemcpyDeviceToHost);
    printf("----------- Check Dict -----------\n");
    bool passed = true;
    unsigned int errNum = 0;
    unsigned int fId;
    unsigned int patIdx;
    for(int m = 0 ; m < RmnfaultList.size(); ++m){
        fId = RmnfaultList[m];
        for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < patNum; ++j){
            patIdx = j - patLoop*paraPatNum;
            if(dictCPU[fId*paraPatNum + patIdx] != dictGPU[fId*paraPatNum + patIdx]){
                printf("[Error]: fault:%d pat:%d CPU:%d GPU:%d\n",m,j,dictCPU[fId*paraPatNum + patIdx],dictGPU[fId*paraPatNum + patIdx]);
                passed = false;
                errNum++;
                if(errNum > 64)
                    return;
            }
        }
    }
    if(passed)
        printf("[Correct] TFS\n");
    free(dictGPU);
}
void SddCudaSim::CheckDynamicAT(PatValue* val_d,float* at_d,int i, CircuitInfo* cirInfo){
    PatValue* val = (PatValue*)malloc(sizeof(PatValue)*(cirInfo->OrigateNum)*4*LS_bkNum);
    float* at = (float*)malloc(sizeof(float)*(cirInfo->OrigateNum)*paraPatNum);
    cudaMemcpy(val        ,val_d       ,sizeof(PatValue)*(cirInfo->OrigateNum)*4*LS_bkNum   ,cudaMemcpyDeviceToHost);
    cudaMemcpy(at         ,at_d       ,sizeof(float)*(cirInfo->OrigateNum)*paraPatNum ,cudaMemcpyDeviceToHost);
    for(int j = 0; j < paraPatNum; ++j){
        if(i*paraPatNum + j == cirInfo->patNum)
            break;
        cout<<"> Simulate Patterns: "<< i*paraPatNum + j<<endl;
        for(int m = 0 ; m < cirInfo->OrigateNum; ++m){
            char t0 = getBitValue(val[m*4+0],val[m*4+1],j);
            char t1 = getBitValue(val[m*4+2],val[m*4+3],j);
            if(t0 != 3 && t1 !=3 && t0 != t1){
                printf("gate:%4d  val:%d->%d  at:%f \n",m,t0,t1,at[m*paraPatNum+j]);
            }
        }
    }
    free(val);
    free(at);
}
void SddCudaSim::CheckFComp(int* SFD,char* partialDict_d,unsigned int* Rmnfault_d,unsigned int* RmnfNum_d,vector<unsigned int>& RmnfaultList,
        int patLoop,int patNum, CircuitInfo* cirInfo, char mode){ // Check fault Compaction
    cudaThreadSynchronize();
    char*         dictGPU      = (char*)malloc(sizeof(char)*cirInfo->fNum*paraPatNum);
    unsigned int* Rmnfault_ptr = (unsigned int*)malloc(sizeof(unsigned int)*(cirInfo->fNum));
    unsigned int* RmnfNumGPU   = (unsigned int*)malloc(sizeof(unsigned int)*2);
    vector<unsigned int > Rmnfault_tmp;
    cudaMemcpy(dictGPU       ,partialDict_d       ,sizeof(char)*(cirInfo->fNum)*paraPatNum ,cudaMemcpyDeviceToHost);
    cudaMemcpy(Rmnfault_ptr  ,Rmnfault_d   ,sizeof(unsigned int)*(cirInfo->fNum)    ,cudaMemcpyDeviceToHost);
    cudaMemcpy(RmnfNumGPU    ,RmnfNum_d    ,sizeof(unsigned int)*2                  ,cudaMemcpyDeviceToHost);
    cudaThreadSynchronize();
    unsigned errNum = 0;
    unsigned int fId;
    unsigned int patIdx;
    if(mode == 0){
        for(int i = 0 ; i < RmnfaultList.size(); ++i){
            fId = RmnfaultList[i];
            for(int j = patLoop*paraPatNum ; j < (patLoop+1)*paraPatNum && j < patNum; ++j){
                patIdx = j - patLoop*paraPatNum;
                if(dictGPU[fId*paraPatNum + patIdx] > 0){
                    Rmnfault_tmp.push_back(fId);
                    break;
                }
            }
        }
        if(Rmnfault_tmp.size() != RmnfNumGPU[1]){
            printf("[Error] RmnfNum CPU:%d GPU:%d\n",Rmnfault_tmp.size(),RmnfNumGPU[1]);
        }
        else{
            printf("[Correct] RmnfNum:%d\n",RmnfNumGPU[1]);
        }
        for(int i = 0 ; i < Rmnfault_tmp.size() && i < RmnfNumGPU[1];++i){
            if(Rmnfault_tmp[i] != Rmnfault_ptr[i]){
                printf("[Error] MOde 0 Rmnfault[%d] CPU:%d GPU:%d\n",i,Rmnfault_tmp[i],Rmnfault_ptr[i]);
                errNum++;
            }
            if(errNum > 10)
                break;
        }
        if(errNum == 0)
            printf("[Correct] Fault Compaction Mode 0\n");
    }
    else if(mode == 1){
        for(int i = 0 ; i < RmnfaultList.size();++i){
            unsigned int QNum = 0;
            unsigned int DNum = 0;
            fId = RmnfaultList[i];
            if((SFD[fId]>>2) >= 0)
                DNum++;
            for(int j = patLoop*paraPatNum ; j < (patLoop+1)*paraPatNum && j < patNum; ++j){
                patIdx = j - patLoop*paraPatNum;
                if(dictGPU[fId*paraPatNum + patIdx] == 1){
                    QNum++;
                }
                else if(dictGPU[fId*paraPatNum + patIdx] == 2){
                    DNum++;
                    if(DNum == 2){
                        break;
                    }
                }
            }
            if(QNum > 0 && DNum < 2)
                Rmnfault_tmp.push_back(fId);
        }
        if(Rmnfault_tmp.size() != RmnfNumGPU[1]){
            printf("[Error] Mode 1 RmnfNum CPU:%d GPU:%d\n",Rmnfault_tmp.size(),RmnfNumGPU[1]);
        }
        else{
            printf("[Correct] RmnfNum:%d\n",RmnfNumGPU[1]);
        }
        for(int i = 0 ; i < Rmnfault_tmp.size() || i < RmnfNumGPU[1]; ++i){
            if(i < Rmnfault_tmp.size() && i < RmnfNumGPU[1]){
                if(Rmnfault_tmp[i] != Rmnfault_ptr[i]){
                    printf("[Error]: Rmnfault[%d] CPU:%d GPU:%d\n",i,Rmnfault_tmp[i],Rmnfault_ptr[i]);
                    errNum++;
                }
            }
            else if(i < Rmnfault_tmp.size() && i >= RmnfNumGPU[1]){
                printf("[Error]: Rmnfault[%d] CPU:%d GPU: X\n",i,Rmnfault_tmp[i]);
                errNum++;
            }
            else if(i >= Rmnfault_tmp.size() && i < RmnfNumGPU[1]){
                printf("[Error]: Rmnfault[%d] CPU: X GPU:%d\n",i,Rmnfault_ptr[i]);
                errNum++;
            }

            if(errNum > 10)
                break;
        }
        if(errNum == 0)
            printf("[Correct] Fault Compaction Mode 1\n");
    }
    free(dictGPU);
    free(Rmnfault_ptr);
    free(RmnfNumGPU);
}
void SddCudaSim::CheckRedundantPat(char* partialDict_d,int* SFD_d,vector<unsigned int>& RmnfaultList,bool* pRdn_d,vector<Pat*>& patList,int patLoop,CircuitInfo* cirInfo){
    bool* pRdn = (bool*)malloc(sizeof(bool)*paraPatNum);
    cudaMemcpy(pRdn,pRdn_d,sizeof(bool)*paraPatNum ,cudaMemcpyDeviceToHost);
    char* dict = (char*)malloc(sizeof(char)*cirInfo->fNum*paraPatNum);
    cudaMemcpy(dict          ,partialDict_d       ,sizeof(char)*(cirInfo->fNum)*paraPatNum ,cudaMemcpyDeviceToHost);
    int* SFDGPU = (int*)malloc(sizeof(int)*cirInfo->fNum);
    cudaMemcpy(SFDGPU        ,SFD_d       ,sizeof(int)*(cirInfo->fNum) ,cudaMemcpyDeviceToHost);
    bool* pRdnCPU = (bool*)malloc(sizeof(bool)*paraPatNum);
    memset(pRdnCPU,true,sizeof(bool)*paraPatNum);
    for(int m = 0 ; m < RmnfaultList.size(); ++m){
        unsigned int fId = RmnfaultList[m];
        int SFD = SFDGPU[fId];
        for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < patList.size(); ++j){
            int patIdx = j - patLoop*paraPatNum;
            if(dict[fId*paraPatNum + patIdx] == 2){
                if((SFD>>2) < 0){
                    pRdnCPU[patIdx] = true;
                    break;
                }
            }
        }
    }
    bool error = false;
    for(int i = 0 ; i < paraPatNum && i+patLoop*paraPatNum < patList.size(); ++i){
        if(pRdn[i] != pRdnCPU[i]){
            printf("[Error]: Redunpant Pattern[%d] GPU:%d CPU:%d\n",patList[i+patLoop*paraPatNum]->id,pRdn[i],pRdnCPU[i]);
            error = true;
        }
    }
    if(error == false)
        printf("[Correct] Redundant Pattern\n");
    free(SFDGPU);
    free(pRdn);
    free(pRdnCPU);
    free(dict);
}
//}}}
//{{{ void Print Function()
void PrintDict(char* partialDict_d,int i,CircuitInfo* cirInfo){
    cudaThreadSynchronize();
    printf("-----------------------------------------------\n");
    char* dict = (char*)malloc(sizeof(char)*cirInfo->fNum*paraPatNum);
    cudaMemcpy(dict          ,partialDict_d       ,sizeof(char)*(cirInfo->fNum)*paraPatNum ,cudaMemcpyDeviceToHost);
    cudaThreadSynchronize();
    for(int m = 0 ; m < cirInfo->fNum; ++m){
        printf("f %8d:",m);
        for(int j = i*paraPatNum; j < (i+1)*paraPatNum && j < cirInfo->patNum; ++j){
            printf("%d",dict[m*paraPatNum + j-i*paraPatNum]);
        }
        printf("\n");
    }
    free(dict);
}
void PrintSFD(char* partialDict_d,int* SFD,int* SFD_d,vector<unsigned int>& RmnfaultList,int patLoop,int patNum, CircuitInfo* cirInfo){
    cudaThreadSynchronize();
    printf("-----------------------------------------------\n");
    char* dict = (char*)malloc(sizeof(char)*cirInfo->fNum*paraPatNum);
    cudaMemcpy(dict          ,partialDict_d       ,sizeof(char)*(cirInfo->fNum)*paraPatNum ,cudaMemcpyDeviceToHost);
    int* SFDGPU = (int*)malloc(sizeof(int)*cirInfo->fNum);
    cudaMemcpy(SFDGPU        ,SFD_d       ,sizeof(int)*(cirInfo->fNum) ,cudaMemcpyDeviceToHost);
    /*
    for(int m = 0 ; m < RmnfaultList.size(); ++m){
        unsigned int fId = RmnfaultList[m];
        printf("f %8d:",fId);
        for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < patNum; ++j){
            printf("%d",dict[fId*paraPatNum + j-patLoop*paraPatNum]);
        }
        if((SFD[fId]&0x02) != 0){
            printf("\t SFD_CPU: DD");
        }
        else if((SFD[fId]>>2) < 0){
            printf("\t SFD_CPU:  R");
        }
        else{
            printf("\t SFD_CPU: %10d | %2d",(SFD[fId]>>2),(SFD[fId]&0x03));
        }
        if((SFDGPU[fId]&0x02) != 0){
            printf("\t SFD_GPU: DD");
        }
        else if((SFDGPU[fId]>>2) < 0){
            printf("\t SFD_GPU:  R");
        }
        else{
            printf("\t SFD_GPU: %10d | %2d",(SFD[fId]>>2),(SFD[fId]&0x03));
        }
        printf("\n");
    }
    */
    for(int m = 0 ; m < cirInfo->fNum; ++m){
        unsigned int fId = m;
        if(fId == 0){
        printf("f %8d:",fId);
        for(int j = patLoop*paraPatNum; j < (patLoop+1)*paraPatNum && j < patNum; ++j){
            printf("%d",dict[fId*paraPatNum + j-patLoop*paraPatNum]);
        }
        if((SFD[fId]&0x02) != 0){
            printf("\t SFD_CPU: DD");
        }
        else if((SFD[fId]>>2) < 0){
            printf("\t SFD_CPU:  R");
        }
        else{
            printf("\t SFD_CPU: %10d | %2d",(SFD[fId]>>2),(SFD[fId]&0x03));
        }
        if((SFDGPU[fId]&0x02) != 0){
            printf("\t SFD_GPU: DD");
        }
        else if((SFDGPU[fId]>>2) < 0){
            printf("\t SFD_GPU:  R");
        }
        else{
            printf("\t SFD_GPU: %10d | %2d",(SFDGPU[fId]>>2),(SFDGPU[fId]&0x03));
        }
        printf("\n");
        }
    }
    free(dict);
    free(SFDGPU);
}
//}}}
