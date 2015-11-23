#include "SddCudaSim.h"
#include <iomanip>
#include <stdio.h>
#include <string.h>
#define GATE_DUMMY 33
bool cmp(const Pat* pat1,const Pat* pat2){
    if(pat1->one_check == pat2->one_check)
        return pat1->id < pat2->id;
    return pat1->one_check > pat2->one_check;
}
int SddCudaSim::OriId2DumId(int gateId){
    return dumCirId[gateId];
}
// Transfer Fuction and Print Function
//{{{ SddCudaSim::cudaDataTrans()
void SddCudaSim::cudaDataTrans(){
    // Use each transfer function to transfer different data
    // Tranafer data structure into one dimension array
    // see cudaArray.xls for detail array layout
    cout << " ==========================================================" << endl;
    cout << " =                  Circuit Trans                         =" << endl;
    cout << " ==========================================================" << endl;
    fout << " ==========================================================" << endl;
    fout << " =                  Circuit Trans                         =" << endl;
    fout << " ==========================================================" << endl;
    // set sdd circuit structure
    unsigned int MAX_INPUT_NUM = 2;
    cirInfo->MAX_INPUT_NUM = MAX_INPUT_NUM;
    cirInfo->OrigateNum = pCir->nGates();
    // trans Circuit
    transCirOri();
    // insert Dummy
    transCirDum();
    
    // transfer Pattern info into 1D array
    cirInfo->patNum = pColl->nPatterns();
    transPat(pColl);
    
    // transfer fault into 1D array 
    transFault();
    
    // transfer delay into 1D array
    transDelay();
    cout<<" [Correct]: Finish Trans\n";
    fout<<" [Correct]: Finish Trans\n";
}
//}}}
//{{{ SddCudaSim::transCir()
void SddCudaSim::transCirOri(){
    // Transfer Origional Circuit into 1D array
    // use a loop to scan all the gate in the circuit
    cout<<" > Trans Circuit Ori ..."<<endl;
    fout<<" > Trans Circuit Ori ..."<<endl;
    unsigned int MAX_INPUT_NUM = cirInfo->MAX_INPUT_NUM;
    cirInfo->cirlvl         = pCir->getLvl();
    gFiOri = (unsigned int*)malloc(sizeof(unsigned int)*cirInfo->OrigateNum*MAX_INPUT_NUM);
    memset(gFiOri,~0,sizeof(unsigned int)*pCir->nGates()*MAX_INPUT_NUM);
    gTypeOri = new unsigned int[pCir->nGates()];
    foOffsetOri = new unsigned int[pCir->nGates() + 1]; 
    foOffsetOri[0] = 0;
    gStrOnLvlOri = new unsigned int[cirInfo->OrigateNum + 1];
    gStrOnLvlOri[0] = 0;
    int currlvl = 0;
    unsigned int foIdx = 0;
    for(unsigned int i = 0 ; i < pCir->nGates(); ++i){
        Gate* g = pCir->getGate(i);
        gTypeOri[i] = getGateType(g);
        if(g->getLvl() > currlvl){
            currlvl++;
            gStrOnLvlOri[currlvl] = g->getId();
        }
        for(unsigned int j = 0 ; j < g->nFos(); ++j){
            Gate* fog = g->getFo(j);
            foVecOri.push_back(fog->getId());
            foIdx++;
            for(unsigned int m = 0 ; m < fog->nFis(); ++m){
                if(fog->getFi(m) == g){
                    foIdxVecOri.push_back(m);
                    break;
                }
            }
        }
        foOffsetOri[i+1] = foIdx;
        for(unsigned int j = 0 ; j < g->nFis(); ++j){
            Gate* fig = g->getFi(j);
            gFiOri[g->getId()*MAX_INPUT_NUM +j] = fig->getId();
        }
    }
    gStrOnLvlOri[currlvl+1] = cirInfo->OrigateNum; 
    foArrayOri = &foVecOri[0];
    foIdxArrayOri = &foIdxVecOri[0];
    //printCirOri();
    
}
void SddCudaSim::printCirOri(){
    for(unsigned int i = 0 ; i < cirInfo->cirlvl + 1; ++i){
        cout<<" Level: "<<i<<"    StrGate: "<<gStrOnLvlOri[i]<<endl;
        fout<<" Level: "<<i<<"    StrGate: "<<gStrOnLvlOri[i]<<endl;
    }
    unsigned int foNum = 0;
    unsigned int maxFo = 0;
    cout<<" --- foArrayOri ---"<<endl;
    cout<<" foNum = "<<foVecOri.size()<<endl;
    fout<<" --- foArrayOri ---"<<endl;
    fout<<" foNum = "<<foVecOri.size()<<endl;
    for(unsigned int i = 0 ; i < pCir->nGates(); ++i){
        cout<<" ---------------------------"<<endl;
        fout<<" ---------------------------"<<endl;
        Gate* g = pCir->getGate(i);
        cout<<"\t Gate: "<<g->getId()<<"  "<<getGateName(g)<<endl;
        fout<<"\t Gate: "<<g->getId()<<"  "<<getGateName(g)<<endl;
        foNum = foOffsetOri[i+1] - foOffsetOri[i];
        if(foNum > maxFo)
            maxFo = foNum;
        cout<<"   Fo: ";
        fout<<"   Fo: ";
        for(unsigned int j = foOffsetOri[i]; j < foOffsetOri[i+1];++j){
            cout<<foArrayOri[j]<<" ";
            fout<<foArrayOri[j]<<" ";
        }
        cout<<endl;
        cout<<"   Fi: ";
        fout<<endl;
        fout<<"   Fi: ";
        for(unsigned int j = 0 ; j < cirInfo->MAX_INPUT_NUM;++j){
            if(gFiOri[i*cirInfo->MAX_INPUT_NUM + j] != (unsigned int)~0){
                cout<<gFiOri[i*cirInfo->MAX_INPUT_NUM + j]<<" ";
                fout<<gFiOri[i*cirInfo->MAX_INPUT_NUM + j]<<" ";
            }
        }
        cout<<endl;
        fout<<endl;
    }
    cout<<" Max Fo: "<<maxFo<<endl;
    cout<<" Fi Ori array:"<<endl;
    fout<<" Max Fo: "<<maxFo<<endl;
    fout<<" Fi Ori array:"<<endl;
    for(unsigned int i = 0; i < cirInfo->OrigateNum;++i){
        unsigned int* cudag = &gFiOri[i*cirInfo->MAX_INPUT_NUM];
        Gate* g = pCir->getGate(i);
        cout<<" --- "<<getGateName(g)<<"("<<i<<") gTypeOri: "<<gTypeOri[i]<<" ---"<<endl;   
        fout<<" --- "<<getGateName(g)<<"("<<i<<") gTypeOri: "<<gTypeOri[i]<<" ---"<<endl;   
        for(unsigned int j = 0 ; j < cirInfo->MAX_INPUT_NUM ; j++){
            if(cudag[j] < cirInfo->OrigateNum){
                Gate* cudagate = pCir->getGate(cudag[j]);
                cout<<" "<<getGateName(cudagate)<<"("<<cudag[j]<<")"<<endl;   
                fout<<" "<<getGateName(cudagate)<<"("<<cudag[j]<<")"<<endl;   
            }
            else{
                cout<<" X"<<endl;
                fout<<" X"<<endl;
            }
        }
    }
}
//}}}
// {{{ SddCudaSim::transCirDum()
void SddCudaSim::transCirDum(){
    // Transfer Circuit with dummy
    // 1. Find number of dummies needed for each level and origional gate in each level
    cout<<" > Trans Circuit Dum ..."<<endl;
    fout<<" > Trans Circuit Dum ..."<<endl;
    // How many gates & dummies in each level
    vector<unsigned int> nGates;
    vector<unsigned int> nDummies;
    nGates.resize(pCir->getLvl(), 0);
    nDummies.resize(pCir->getLvl(), 0);
    for (unsigned int i = 0; i < pCir->nGates(); ++i) {
        Gate *g = pCir->getGate(i);
        int maxFoLvl = 0;
        for (unsigned int j = 0; j < g->nFos(); ++j) {
            Gate *fo = g->getFo(j);
            int Lvl;
            if(fo->getType() == Gate::PO || fo->getType() == Gate::PPO ){
                Lvl = g->getLvl() + 1;
            }
            else
                Lvl = fo->getLvl();
            if (Lvl > maxFoLvl)
                maxFoLvl = Lvl;
        }
        for (int j = g->getLvl() + 1; j < maxFoLvl; ++j)
            nDummies[j]++;
        // Add PO & PPO into closest level
        if(g->getType() == Gate::PO || g->getType() == Gate::PPO)
            nGates[g->getFi(0)->getLvl()+1]++;
        else
            nGates[g->getLvl()]++;
    }

    gStrOnLvlDum = new unsigned int[pCir->getLvl()+1];
    gStrOnLvlDum[0] = 0;        // Record started gate ID in every level
    unsigned int gateNum = 0;   // Gate number in total
    // 2. Determine number of gates per level
    unsigned int nGatesPerLvl = 0;
    for (int i = 0; i < pCir->getLvl(); ++i) {
        if (nDummies[i] + nGates[i] > nGatesPerLvl)
            nGatesPerLvl = nDummies[i] + nGates[i];
        gateNum += (nDummies[i] + nGates[i]);
        gStrOnLvlDum[i+1] = gateNum;
    }
    foOffsetDum  = new unsigned int[gateNum + 1];
    foOffsetDum[0] = 0;
    cirInfo->gatesPerLvl = nGatesPerLvl;
    cirInfo->DumgateNum     = gateNum;
    gTypeDum = (unsigned int*)malloc(sizeof(unsigned int)*gateNum);
    gFiDum   = (unsigned int*)malloc(sizeof(unsigned int)*gateNum*cirInfo->MAX_INPUT_NUM);
    // gDum2Ori is used to transfer dummy circuit Id to orig circuit Id
    gDum2Ori = (unsigned int*)malloc(sizeof(unsigned int)*gateNum);

    // initial gTypeDum to be DUMMY Gate (33)
    memset(gTypeDum,GATE_DUMMY,sizeof(unsigned int)*gateNum);
    memset(gFiDum,~0,sizeof(unsigned int)*gateNum*cirInfo->MAX_INPUT_NUM);
    memset(gDum2Ori,~0,sizeof(unsigned int)*gateNum);
    
    // Calculate Dummy Circuit Id (dumCirId) for each gate 
    // gList is a temporary list to relate dumCirId with gate pointer
    Gate** gList = new Gate*[gateNum];
    memset(gList,0,sizeof(Gate*)*gateNum);
    vector<int> lvlId;          // Level Id has ben used in each level
    
    // dumCirId is used transfer gateId in ori circuit to dummy circuit
    dumCirId.resize(pCir->nGates());
    for(int i = 0 ; i < pCir->getLvl();++i){
        lvlId.push_back(gStrOnLvlDum[i]);
    }
    int currlvl = 0;
    for(unsigned int i = 0 ; i < pCir->nGates();++i){
        Gate* g = pCir->getGate(i);
        int currlvl;
        if(g->getType() == Gate::PO || g->getType() == Gate::PPO)
            currlvl = g->getFi(0)->getLvl() + 1;
        else
            currlvl = g->getLvl();
        dumCirId[g->getId()] = lvlId[currlvl];
        gTypeDum[dumCirId[g->getId()]] = getGateType(g);
        gList[dumCirId[g->getId()]] = g;
        gDum2Ori[dumCirId[g->getId()]] = i;
        lvlId[currlvl]++;
    }
    vector<vector<unsigned int> >    foList;
    vector<vector<unsigned int> >    fiList;    // Use 2 fiList is to sort the gate input 
    vector<vector<unsigned int> >    fiListDum; // of dum circuit as origional circuit
    foList.resize(gateNum);
    fiList.resize(gateNum);
    fiListDum.resize(gateNum);
    vector<unsigned int>    foIdxList;
    currlvl = 0;
    // 3. Add dummy depend on fanout cross level > 1
    for(unsigned int i = 0 ; i < gateNum; ++i){
        bool insertDummy = false;
        if(i == gStrOnLvlDum[currlvl + 1])
            currlvl++;
        unsigned int dumId = 0;
        if(gList[i] == 0){  // Id i in gList is a dummy gate
            for(unsigned int j = 0 ; j < foList[i].size();++j){
                unsigned int foId = foList[i][j];
                if(gStrOnLvlDum[currlvl + 2] <= foId){
                    // transfer dummy to output dummy
                    // dumId is the fanout dummy gate Id of current gate
                    // transfer current dummy gate's fanout to output dummy
                    dumId = gStrOnLvlDum[currlvl + 1] + nGates[currlvl + 1];
                    foList[dumId].push_back(foId);
                    foList[i].erase(foList[i].begin()+ j);
                    j--;
                    insertDummy = true;
                }
                else{
                    fiList[foId].push_back(i);
                }
            }
        }
        else{   // not dummy gate
            Gate* g = gList[i];
            if(g->getType() == Gate::PO || g->getType() == Gate::PPO)
                continue;
            for(unsigned int j = 0 ; j < g->nFos(); ++j){
                Gate* fog = g->getFo(j);
                if(fog->getType() == Gate::PO || fog->getType() == Gate::PPO){
                    foList[i].push_back(dumCirId[fog->getId()]);
                    fiList[dumCirId[fog->getId()]].push_back(i);
                }
                else{
                    if(g->getLvl() + 1 < fog->getLvl()){
                        // dumId is the fanout dummy gate Id of current gate
                        dumId = gStrOnLvlDum[g->getLvl() + 1] + nGates[g->getLvl() + 1];
                        foList[dumId].push_back(dumCirId[fog->getId()]);
                        insertDummy = true;
                    }
                    else{
                        foList[i].push_back(dumCirId[fog->getId()]);
                        fiList[dumCirId[fog->getId()]].push_back(i);
                    }
                }
            }
        }
        if(insertDummy){    // increase dummy
            foList[i].push_back(dumId);
            fiList[dumId].push_back(i);
            nGates[currlvl + 1]++;
            gTypeDum[dumId] = GATE_DUMMY; // dummy Gate
            gDum2Ori[dumId] = gDum2Ori[i];
        }
    }
    // 4. sort gate's fin to Origional Order
    unsigned int nfo = 0;
    for(unsigned int i = 0 ; i < gateNum;++i){
        if(gTypeDum[i] == GATE_DUMMY){
            for(unsigned int j = 0 ; j < fiList[i].size(); ++j){
                gFiDum[i*cirInfo->MAX_INPUT_NUM + 0] = fiList[i][j];
            }
        }
        else{
            Gate* g = pCir->getGate(gDum2Ori[i]);
            for(unsigned int j = 0 ; j < fiList[i].size();++j){
                for(unsigned int m = 0 ; m < g->nFis();++m){
                    if(gDum2Ori[fiList[i][j]] == g->getFi(m)->getId()){
                        gFiDum[i*cirInfo->MAX_INPUT_NUM + m] = fiList[i][j];
                        break;
                    }
                }
            }
        }
        for(unsigned int j = 0 ; j < foList[i].size(); ++j){
            foVecDum.push_back(foList[i][j]);
            nfo++;
            if(gTypeDum[foList[i][j]] == GATE_DUMMY){
                foIdxVecDum.push_back(0);
            }
            else{
                Gate* g = pCir->getGate(gDum2Ori[foList[i][j]]);
                for(unsigned int m = 0 ; m < g->nFis();++m){
                    if(g->getFi(m)->getId() == gDum2Ori[i]){
                        foIdxVecDum.push_back(m);
                        break;
                    }
                }
            }
        }
        foOffsetDum[i+1] = nfo;
    }
    for(unsigned int i = 0 ; i < pCir->nSeqs();++i){
        Gate* ppi = pCir->getPpi(i);
        Gate* fi  = ppi->getFi(0);
        gFiDum[dumCirId[ppi->getId()]*cirInfo->MAX_INPUT_NUM + 0 ] = dumCirId[fi->getId()];
    }
    foArrayDum = &foVecDum[0];
    foIdxArrayDum = &foIdxVecDum[0];
    cout<<" ------------------------------------------\n";
    cout<<" | Orig  Gate Size = "<<setw(10)<<cirInfo->OrigateNum<<"           |\n";
    cout<<" | Final Gate Size = "<<setw(10)<<gateNum<<"           |\n";
    cout<<" | Expansion Ratio = "<<setw(10)<<(float)gateNum/(cirInfo->OrigateNum)<<"           |\n";
    cout<<" ------------------------------------------\n";
    
    fout<<" ------------------------------------------\n";
    fout<<" | Orig  Gate Size = "<<setw(10)<<cirInfo->OrigateNum<<"           |\n";
    fout<<" | Final Gate Size = "<<setw(10)<<gateNum<<"           |\n";
    fout<<" | Expansion Ratio = "<<setw(10)<<(float)gateNum/(cirInfo->OrigateNum)<<"           |\n";
    fout<<" ------------------------------------------\n";
    //printCirDum();
}

void SddCudaSim::printCirDum(){
    unsigned int gateNum = cirInfo->DumgateNum;
    unsigned int currlvl = 0;
    for(unsigned int i = 0 ; i < gateNum; ++i){
        cout<<" Gate: ("<<i<<")      "<<(gTypeDum[i] == GATE_DUMMY ? "DUMMY": getGateName(pCir->getGate(gDum2Ori[i])))<<endl;
        cout<<"   Fo: ";
        fout<<" Gate: ("<<i<<")      "<<(gTypeDum[i] == GATE_DUMMY ? "DUMMY": getGateName(pCir->getGate(gDum2Ori[i])))<<endl;
        fout<<"   Fo: ";
        for(unsigned int j = foOffsetDum[i]; j < foOffsetDum[i+1];++j){
            cout<<foArrayDum[j]<<" ";
            fout<<foArrayDum[j]<<" ";
        }
        cout<<endl;
        cout<<"   Fi: ";
        fout<<endl;
        fout<<"   Fi: ";
        for(unsigned int j = 0 ; j < cirInfo->MAX_INPUT_NUM;++j){
            if(gFiDum[i*cirInfo->MAX_INPUT_NUM + j] != (unsigned int)~0){
                cout<<gFiDum[i*cirInfo->MAX_INPUT_NUM + j]<<" ";
                fout<<gFiDum[i*cirInfo->MAX_INPUT_NUM + j]<<" ";
            }
        }
        cout<<endl;
        fout<<endl;
        if(i+1 == gStrOnLvlDum[currlvl+1]){
            cout<<" ---------------------------------------"<<endl;
            fout<<" ---------------------------------------"<<endl;
            currlvl++;
        }
    }
    cout<<" Fi array:"<<endl;
    fout<<" Fi array:"<<endl;
    for(unsigned int i = 0; i < gateNum;++i){
        unsigned int* cudag = &gFiDum[i*cirInfo->MAX_INPUT_NUM];
        if(gTypeDum[i] == GATE_DUMMY ){
            cout<<" --- "<<"DUMMY";
            cout<<"  ("<<i<<")  gTypeDum: "<<gTypeDum[i]<<" ---"<<endl;   
            fout<<" --- "<<"DUMMY";
            fout<<"  ("<<i<<")  gTypeDum: "<<gTypeDum[i]<<" ---"<<endl;   
        }
        else{
            cout<<" --- "<<getGateName(pCir->getGate(gDum2Ori[i]))<<"("<<i<<") gTypeDum: "<<gTypeDum[i]<<" ---"<<endl;   
            fout<<" --- "<<getGateName(pCir->getGate(gDum2Ori[i]))<<"("<<i<<") gTypeDum: "<<gTypeDum[i]<<" ---"<<endl;   
        }
        for(unsigned int j = 0 ; j < cirInfo->MAX_INPUT_NUM ; j++){
            if(cudag[j]<gateNum){
                if(gTypeDum[cudag[j]] == GATE_DUMMY ){
                    cout<<" DUMMY"<<" ("<<cudag[j]<<")"<<endl;   
                    fout<<" DUMMY"<<" ("<<cudag[j]<<")"<<endl;   
                }
                else{
                    cout<<" "<<getGateName(pCir->getGate(gDum2Ori[cudag[j]]))<<"("<<cudag[j]<<")"<<endl;   
                    fout<<" "<<getGateName(pCir->getGate(gDum2Ori[cudag[j]]))<<"("<<cudag[j]<<")"<<endl;   
                }
            }
            else{
                cout<<" X"<<endl;
                fout<<" X"<<endl;
            }
        }
    }
    cout<<endl;
    fout<<endl;
    currlvl = 0;
    cout<<" Dum2Ori array: "<<endl;
    fout<<" Dum2Ori array: "<<endl;
    for(unsigned int i = 0 ; i < gateNum;i++){
        if(i == gStrOnLvlDum[currlvl]){
            cout<<" ---Lvl:"<<currlvl<<"---"<<endl;
            fout<<" ---Lvl:"<<currlvl<<"---"<<endl;
            currlvl++;
        }
        if(gDum2Ori[i]<gateNum){
            cout<<" "<<i<<": "<<getGateName(pCir->getGate(gDum2Ori[i]))<<" id:"<<gDum2Ori[i]<<endl;
            fout<<" "<<i<<": "<<getGateName(pCir->getGate(gDum2Ori[i]))<<" id:"<<gDum2Ori[i]<<endl;
        }
        else{
            cout<<" "<<i<<": "<<"X"<<endl;
            fout<<" "<<i<<": "<<"X"<<endl;
        }
    }
    int foNum = 0;
    int maxFo = 0;
    int foIdx =0;
    int id = 0;
    for(unsigned int i = 0 ; i < cirInfo->cirlvl+1;++i){
        printf(" gStrLvl[%3d]: %d\n",i,gStrOnLvlDum[i]);
    }
    cout<<" --- foArrayDum ---"<<endl;
    fout<<" --- foArrayDum ---"<<endl;
    for(unsigned int i = 0 ; i < gateNum; ++i){
        cout<<"\t Gate: "<<i<<endl;
        fout<<"\t Gate: "<<i<<endl;
        foNum = foOffsetDum[i+1] - foOffsetDum[i];
        if(foNum > maxFo){
            maxFo = foNum;
            id = i;
        }
        for(int j = 0 ; j < foNum; j++){
            cout<<"  Fo: "<<foVecDum[foIdx]<<"  fo: "<<foOffsetDum[i]<<"   FiIdx: "<<foIdxVecDum[foIdx]<<endl;
            fout<<"  Fo: "<<foVecDum[foIdx]<<"  fo: "<<foOffsetDum[i]<<"   FiIdx: "<<foIdxVecDum[foIdx]<<endl;
            foIdx++;
        }
        cout<<" ------------------------"<<endl;
        fout<<" ------------------------"<<endl;
    }
    cout<<" Max Fo: "<<maxFo<<" gate: "<<id<<endl;
    fout<<" Max Fo: "<<maxFo<<" gate: "<<id<<endl;
}
//}}}
//{{{ SddCudaSim::transPat()
void SddCudaSim::transPat(PatternColl* newpColl){
    cout<<" > Trans Pattern..."<<endl;
    fout<<" > Trans Pattern..."<<endl;
    // Ignore Pi: CK test_si and test_se
    unsigned int patNum   = newpColl->nPatterns();
    unsigned int piNum    = pCir->nPis();
    unsigned int ppiNum   = newpColl->nScans();
    unsigned int poNum    = pCir->nPos();
    cirInfo->piNum  = piNum;
    cirInfo->ppiNum = ppiNum;
    cirInfo->poNum  = poNum;
    pat_t0 = new PatValue[((patNum-1)/paraPatNum+1)*(piNum+ppiNum)*2];
    pat_t1 = new PatValue[((patNum-1)/paraPatNum+1)*(piNum+ppiNum)*2];
    unsigned int patStart,patEnd; 
    unsigned int patOffset = 0;
    //
    if(firstTrans){
        newpColl->cirPiId2PatId_ = new unsigned int[piNum];
        newpColl->cirScanId2PatId_ = new unsigned int[ppiNum];
    }
    for (unsigned int  i = 0 ; i < patNum; i = i+ paraPatNum) {
        patStart = i;
        if( i + paraPatNum <= patNum)
            patEnd = patStart + paraPatNum;
        else
            patEnd = patNum;
        
        // set each bit of the PI's value
        unsigned int bitIdx;
        PatValue mask = 0x1; 
        for (bitIdx = 0; patStart < patEnd ; patStart ++ , bitIdx++) {
            Pattern *pat = newpColl->getPattern(patStart); 
            // set Two time frame Pi gate's value  
            // start to pack one pattern into parallel value
            for(unsigned int j = 0 ; j < piNum ; j++) {
                // Ignore first 3 Pi Values: CK, test_si, test_se
                Gate* g = pCir->getPi(j);
                unsigned int piIdx;
                if(firstTrans){ // first time of transfer pattern
                    piIdx = newpColl->getPiIdx(getGateName(g));
                    newpColl->cirPiId2PatId_[j] = piIdx;
                }
                else{
                    piIdx = newpColl->cirPiId2PatId_[j];
                }
                if (pat->getPi(piIdx,0) == H){
                    pat_t0[patOffset*(piNum+ppiNum)*2+j*2+0] &= ~(mask<<bitIdx);
                    pat_t0[patOffset*(piNum+ppiNum)*2+j*2+1] |= (mask<<bitIdx);
                }
                else if(pat->getPi(piIdx,0) == L){
                    pat_t0[patOffset*(piNum+ppiNum)*2+j*2+0] |= (mask<<bitIdx);
                    pat_t0[patOffset*(piNum+ppiNum)*2+j*2+1] &= ~(mask<<bitIdx);
                }
                else{
                    pat_t0[patOffset*(piNum+ppiNum)*2+j*2+0] &= ~(mask<<bitIdx);
                    pat_t0[patOffset*(piNum+ppiNum)*2+j*2+1] &= ~(mask<<bitIdx);
                }
                if (pat->getPi(piIdx,1) == H){
                    pat_t1[patOffset*(piNum+ppiNum)*2+j*2+0] &= ~(mask<<bitIdx);
                    pat_t1[patOffset*(piNum+ppiNum)*2+j*2+1] |= (mask<<bitIdx);
                }
                else if(pat->getPi(piIdx,1) == L){
                    pat_t1[patOffset*(piNum+ppiNum)*2+j*2+0] |= (mask<<bitIdx);
                    pat_t1[patOffset*(piNum+ppiNum)*2+j*2+1] &= ~(mask<<bitIdx);
                }
                else{
                    pat_t1[patOffset*(piNum+ppiNum)*2+j*2+0] &= ~(mask<<bitIdx);
                    pat_t1[patOffset*(piNum+ppiNum)*2+j*2+1] &= ~(mask<<bitIdx);
                }
            }
            for(unsigned int j = 0 ; j < ppiNum; j++) {
                Gate* g = pCir->getPpi(j);
                unsigned int ppiIdx;
                if(firstTrans){ // first time of transfer pattern
                    ppiIdx = newpColl->getScanIdx(getGateName(g));
                    newpColl->cirScanId2PatId_[j] = ppiIdx;
                }
                else{
                    ppiIdx = newpColl->cirScanId2PatId_[j];
                }
                if (pat->getPpi(ppiIdx) == H){
                    pat_t0[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+0] &= ~(mask<<bitIdx);
                    pat_t0[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+1] |= (mask<<bitIdx);
                }
                else if(pat->getPpi(ppiIdx) == L){
                    pat_t0[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+0] |= (mask<<bitIdx);
                    pat_t0[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+1] &= ~(mask<<bitIdx);
                }
                else{
                    pat_t0[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+0] &= ~(mask<<bitIdx);
                    pat_t0[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+1] &= ~(mask<<bitIdx);
                }
                // this part may be related to new structure
                pat_t1[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+0] &= ~(mask<<bitIdx);
                pat_t1[patOffset*(piNum+ppiNum)*2+(j+piNum)*2+1] &= ~(mask<<bitIdx);
            }       
            // Save the hold and capture into the last PPI's timeframe 1 h_ value
            pat_t1[(patOffset+1)*(piNum+ppiNum)*2-1] |= (((size_t)pat->getClk(0))<<bitIdx);
        }
        // fill remain unused pattern to be undifined
        for(; bitIdx < paraPatNum; bitIdx++,patEnd++){
            for(unsigned int j = 0 ; j < piNum+ppiNum; j++) {
                pat_t0[patOffset*(piNum+ppiNum)*2+j*2+0] |= (mask<<bitIdx);
                pat_t0[patOffset*(piNum+ppiNum)*2+j*2+1] |= (mask<<bitIdx);
                pat_t1[patOffset*(piNum+ppiNum)*2+j*2+0] |= (mask<<bitIdx);
                pat_t1[patOffset*(piNum+ppiNum)*2+j*2+1] |= (mask<<bitIdx);
            }
        }
        patOffset++;
    }
    if(firstTrans)
        firstTrans = false;
    //printPat();
}
void SddCudaSim::printPat(){
    // test pattern output
    unsigned int patNum = cirInfo->patNum;
    unsigned int piNum  = cirInfo->piNum;
    unsigned int ppiNum = cirInfo->ppiNum;
    for(unsigned int i = 0; i < (patNum-1)/paraPatNum + 1; ++i){
        cout<<"-------PATTERN: "<<i<<"---------"<<endl;
        fout<<"-------PATTERN: "<<i<<"---------"<<endl;
        for(unsigned j = 0 ; j < piNum+ppiNum; ++j){
            cout<<" >PI: "<<setw(3)<<j<<" t0 = ";
            fout<<" >PI: "<<setw(3)<<j<<" t0 = ";
            PrintBinaryValue(pat_t0[i*(piNum+ppiNum)*2+j*2+0],pat_t0[i*(piNum+ppiNum)*2+j*2+1]);
            cout<<" >PI: "<<setw(3)<<j<<" t1 = ";
            fout<<" >PI: "<<setw(3)<<j<<" t1 = ";
            PrintBinaryValue(pat_t1[i*(piNum+ppiNum)*2+j*2+0],pat_t1[i*(piNum+ppiNum)*2+j*2+1]);
        }
    }
}
void SddCudaSim::PrintBinaryValue(PatValue Val0,PatValue Val1){
   for(int i = paraPatNum-1 ;i >= 0; --i){
      char BitVal0 = getBitValue(Val0,i);
      char BitVal1 = getBitValue(Val1,i);
      if(BitVal0 == 1 && BitVal1 == 0){
         cout<<'0';
         fout<<'0';
      }
      else if(BitVal0 == 0 && BitVal1 == 1){
         cout<<'1';
         fout<<'1';
      }
      else if(BitVal0 == 0 && BitVal1 == 0){
         cout<<'X';
         fout<<'X';
      }
      else{
        cout<<'D';
        fout<<'D';
      }
   }
   cout<<endl;
   fout<<endl;
}
char SddCudaSim::getBitValue(PatValue &pv, const int& i) {
    return (pv & ((PatValue)0x01 << i)) == 0 ? 0 : 1;
}
char SddCudaSim::getBitValue(PatValue& l_,PatValue& h_, const int& bitIdx) {
    PatValue v0 =  (l_ & ((PatValue)0x01 << bitIdx)) == 0 ? 0 : 1;
    PatValue v1 =  (h_ & ((PatValue)0x01 << bitIdx)) == 0 ? 0 : 1;
    if(v0 == 0 && v1 == 1){
        return 1;
    }
    else if(v0 == 1 && v1 == 0){
        return 0;
    }
    else if(v0 == 0 && v1 == 0){
        return 2; // 2 = X
    }
    else{
        return 3; // 3 = D
    }
}
//}}}
//{{{ SddCudaSim::transFault()
void SddCudaSim::transFault(){
    // Extract Fault into 1D array
    cout<<" > Fault Trans..."<<endl;
    fout<<" > Fault Trans..."<<endl;
    unsigned int fNum = 0;
    vector<vector<CudaFault*> >     faultLvlVec;
    faultLvlVec.resize(pCir->getLvl());
    // Generate fList without sorted by level
    for(unsigned int i = 0; i < pCir->nGates(); ++i){
        Gate* g = pCir->getGate(i);
        if(g->getType() == Gate::PO || g->getType() == Gate::PPO)
            continue;
        // every gate's output have faults
        CudaFault* f = (CudaFault*)malloc(sizeof(CudaFault));
        f->fType = 0;       // 0 = STR
        f->fLine = 0;
        f->fGate = dumCirId[g->getId()];
        faultLvlVec[g->getLvl()].push_back(f);
        
        f = (CudaFault*)malloc(sizeof(CudaFault));
        f->fType = 1;       // 1 = STR
        f->fLine = 0;
        f->fGate = dumCirId[g->getId()];
        faultLvlVec[g->getLvl()].push_back(f);
        fNum += 2;
        // if gate has multiple output
        // every output gate will has input fault on related pin
        if(g->nFos() > 1){
            for(unsigned int j = 0 ; j < g->nFos();++j){
                Gate* fog = g->getFo(j);
                for(unsigned int m = 0 ; m < fog->nFis();++m){
                    if(fog->getFi(m) == g){
                        CudaFault* f = (CudaFault*)malloc(sizeof(CudaFault));
                        f->fType = 0;       // 0 = STR
                        f->fLine = m + 1;
                        f->fGate = dumCirId[fog->getId()];
                        int folvl;
                        if(fog->getType() == Gate::PO || fog->getType() == Gate::PPO)
                            folvl = fog->getFi(0)->getLvl() + 1;
                        else
                            folvl = fog->getLvl();
                        faultLvlVec[folvl].push_back(f);

                        f = (CudaFault*)malloc(sizeof(CudaFault));
                        f->fType = 1;       // 1 = STR
                        f->fLine = m + 1;
                        f->fGate = dumCirId[fog->getId()];
                        faultLvlVec[folvl].push_back(f);
                        fNum += 2;
                        break;
                    }
                }
            }
        }
    }
    cirInfo->fNum = fNum;
    fLvl = (unsigned int*)malloc(sizeof(unsigned int)*fNum);
    fList = (unsigned int*)malloc(sizeof(unsigned int)*fNum*3);
    fStrOnLvl = (unsigned int*)malloc(sizeof(unsigned int)*(pCir->getLvl()+1));
    fStrOnLvl[0] = 0;
    unsigned int  fIdx = 0;
    // Push fault into fList level by level
    for(unsigned int i = 0 ; i < cirInfo->cirlvl; ++i){    
        for(unsigned int j = 0 ; j < faultLvlVec[i].size();++j){
            CudaFault* f = faultLvlVec[i][j];
            fList[fIdx*3 + 0] = f->fType;          // 0 = STR
            fList[fIdx*3 + 1] = f->fLine;
            fList[fIdx*3 + 2] = f->fGate;
            fLvl[fIdx] = i;
            fIdx++;
        }
        fStrOnLvl[i+1] = fIdx;

    }
    cout<<" ------------------------------------------\n";
    cout<<" | TransFault Size ="<<setw(10)<<fNum<<"            |\n";
    cout<<" ------------------------------------------\n";
    fout<<" ------------------------------------------\n";
    fout<<" | TransFault Size ="<<setw(10)<<fNum<<"            |\n";
    fout<<" ------------------------------------------\n";
    //printFault();
}
void SddCudaSim::printFault(){
    cout<<" ------- Fault Level ---------"<<endl;
    fout<<" ------- Fault Level ---------"<<endl;
    unsigned int fNum = cirInfo->fNum;
    for(unsigned int i = 0 ; i < cirInfo->cirlvl+1;++i){
        cout<<" Lvl: "<<i<<" StartFault: "<<fStrOnLvl[i]<<endl;
        fout<<" Lvl: "<<i<<" StartFault: "<<fStrOnLvl[i]<<endl;
    }
    cout<<" ------- Fault List  ---------"<<endl;
    fout<<" ------- Fault List  ---------"<<endl;
    for(unsigned int i= 0 ; i < fNum; ++i){
        cout<<" fID: "<<i<<" type: "<<fList[i*3 + 0]<<" line: "<<fList[i*3 + 1]<<" DumGate: "<<fList[i*3 + 2]<<" fLvl: "<<fLvl[i]<<endl;
        fout<<" fID: "<<i<<" type: "<<fList[i*3 + 0]<<" line: "<<fList[i*3 + 1]<<" DumGate: "<<fList[i*3 + 2]<<" fLvl: "<<fLvl[i]<<endl;
    }
}
//}}}
//{{{ SddCudaSim::getGateName()
const char* SddCudaSim::getGateName(Gate* g){
    size_t gateId = g->getId(); 
    if (g->getType() == Gate::PI) {
        return design->getTop()->getModTerm(gateId + 3)->getName();
    }
    else if(g->getType() == Gate::PO){
        return design->getTop()->getModTerm(gateId-pCir->nCombs()-pCir->nSeqs()+3)->getName();
    }
    else{
        return g->getOcc()->getModInst()->getName();
    }
    return "";
}
//}}}
//{{{ SddCudaSim::getGateType()
unsigned int SddCudaSim::getGateType(Gate* g){
    // Transfer gType to Cuda Gate Type
    switch(g->getType()){
        case Gate::PI:
            return 0;
        case Gate::PO:
            return 1;
        case Gate::PPI:
            return 2;
        case Gate::PPO:
            return 3;
        case Gate::INV:
            return 29;
        case Gate::BUF:
            return 28;
        case Gate::AND:
            return 5 + g->nFis();
        case Gate::NAND:
            return 9 + g->nFis();
        case Gate::OR:
            return 13 + g->nFis();
        case Gate::NOR:
            return 17 + g->nFis();
        case Gate::XOR:
            return 21 + g->nFis();
        case Gate::XNOR:
            return 24 + g->nFis();
        case Gate::TIE0:
            return 5;
        case Gate::TIE1:
            return 4;
        case Gate::MUX:
        case Gate::TIEX:
        case Gate::TIEZ:
        default:
            return -1;
    }
    return -1;
}
//}}}
//{{{ SddCudaSim::transDelay()
void SddCudaSim::transDelay(){
    cout<<" > Delay Trans..."<<endl;
    fout<<" > Delay Trans..."<<endl;
    dList = (float*)malloc(sizeof(float)*cirInfo->OrigateNum*8);
    memset(dList,0.0,sizeof(float)*cirInfo->OrigateNum*8);
    for(unsigned int i = 0 ; i < pCir->nGates() ; i++) {
        Gate* g = pCir->getGate(i);
        for(unsigned int j = 0; j < g->nFis(); ++j){
            dList[8*i + 2*j + 0] = g->getDelay( j , Gate::RISE);
            dList[8*i + 2*j + 1] = g->getDelay( j , Gate::FALL);
        }
    }
    //printDelay();
}
void SddCudaSim::printDelay(){
    cout<<" ------ Gate Delay array -------"<<endl;
    fout<<" ------ Gate Delay array -------"<<endl;
    for(unsigned int i = 0; i < pCir->nGates();++i){
        cout<<" ------------ "<<getGateName(pCir->getGate(i))<<"("<<i<<")"<<" -------------"<<endl;   
        fout<<" ------------ "<<getGateName(pCir->getGate(i))<<"("<<i<<")"<<" -------------"<<endl;   
        for(unsigned int j = 0 ; j < cirInfo->MAX_INPUT_NUM; ++j){
            cout<<" fi: "<<j<<" Rising: "<<setw(5)<<dList[8*i + 2*j + 0]<<" Falling: "<<setw(5)<<dList[8*i + 2*j + 1]<<endl;
            fout<<" fi: "<<j<<" Rising: "<<setw(5)<<dList[8*i + 2*j + 0]<<" Falling: "<<setw(5)<<dList[8*i + 2*j + 1]<<endl;
        }
    }
}
//}}}
// ReOrder and  Selection Function
//{{{ void SddCudaSim::SortNCompacttPattern()
void SddCudaSim::SortNCompactPattern(vector<Pat*>& patList){
    // Remove redundant pattern from patList
    vector<Pat*>    patList_tmp = patList;
    patList.clear();
    for(int i = 0 ; i < patList_tmp.size(); ++i){
        if(patList_tmp[i]->redundant == true){
        }
        else{
            patList.push_back(patList_tmp[i]);
        }
    }
    patList_tmp.clear(); 
    stable_sort(patList.begin(),patList.end(),cmp);
    // Initialize new pattern coll
    PatternColl* newpColl = new PatternColl(pColl);
    // Add pattern into new pattern coll
    for(int i = 0 ; i < patList.size(); ++i){
        newpColl->addPattern(pColl->getPattern(patList[i]->id));
    }
    free(pat_t0);
    free(pat_t1);
    transPat(newpColl);
    delete newpColl;

    //printf("----- ReOrder Pattern -----\n") ;
    //for(int i = 0 ; i < patList.size(); ++i){
    //    printf("patList[%2d]:%2d one_check:%2d\n",i,patList[i]->id,patList[i]->one_check);
    //}
}
//}}}
//{{{ void SddCudaSim::OneCheckCal()
void SddCudaSim::OneCheckCal(int* SFD,vector<Pat*>& patList,vector<unsigned int>& RmnfaultVec,vector<Pat*>& essPat,int patLoop){
    // Calculation one check value for every Pat base on SFD
    vector<unsigned int>    RmnfaultVec_tmp = RmnfaultVec;
    RmnfaultVec.clear();
    unsigned int patNum = patList.size();
    for(unsigned int i = 0 ; i < RmnfaultVec_tmp.size(); ++i){
        unsigned int fId = RmnfaultVec_tmp[i];
        if((SFD[fId]>>2) < 0){
            RmnfaultVec.push_back(fId);
        }
        else if(((SFD[fId]&0x02) != 0) && ((SFD[fId]&0x01) != 0) ){ // double detect
            if(essPat[fId] != 0){
                essPat[fId]->one_check -= 1;
                essPat[fId] = 0;
            }
        }
        else if((SFD[fId]>>2) >= 0){
            RmnfaultVec.push_back(fId);
            if(SFD[fId]&0x01 != 0){
                int patIdx = (SFD[fId] >>2) + patLoop*paraPatNum;
                patList[patIdx]->one_check += 1;
                essPat[fId] = patList[patIdx];
            }
        }
        SFD[fId] &= ((~0)<<1);
    }
}
//}}}
//{{{ void SddCudaSim::DumpPattern()
void SddCudaSim::DumpPattern(vector<Pat*>& patList){
    printf(" > Dump Pattern ...\n");
    // Initialize final pattern coll
    PatternColl* finalpColl = new PatternColl(pColl);
    
    // Add pattern into final pattern coll
    for(int i = patList.size()-1 ; i >= 0;--i)
        finalpColl->addPattern(pColl->getPattern(patList[i]->id));
    finalpColl->print(outSelPat);
    outSelPat.close();
}

//}}}
