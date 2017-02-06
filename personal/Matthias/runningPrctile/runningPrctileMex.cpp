#include <matrix.h>
#include <mex.h>
#include <algorithm>
#include "runningPrctile.cpp"

/* Definitions to keep compatibility with earlier versions of ML */
#ifndef MWSIZE_MAX
typedef int mwSize;
typedef int mwIndex;
typedef int mwSignedIndex;

#if (defined(_LP64) || defined(_WIN64)) && !defined(MX_COMPAT_32)
/* Currently 2^48 based on hardware limitations */
# define MWSIZE_MAX    281474976710655UL
# define MWINDEX_MAX   281474976710655UL
# define MWSINDEX_MAX  281474976710655L
# define MWSINDEX_MIN -281474976710655L
#else
# define MWSIZE_MAX    2147483647UL
# define MWINDEX_MAX   2147483647UL
# define MWSINDEX_MAX  2147483647L
# define MWSINDEX_MIN -2147483647L
#endif
#define MWSIZE_MIN    0UL
#define MWINDEX_MIN   0UL
#endif

using namespace std;

// void runningPrctile(double* dataArray, double* resultArray,
// 	const size_t dataArrayLength, const size_t winLength,
// 	size_t nth);

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    
    // Check for proper number of arguments.
    if(nrhs!=3) {
        mexErrMsgIdAndTxt( "runningPrctileMex:invalidNumInputs",
                "Exactly three inputs required.");
    } else if(nlhs>1) {
        mexErrMsgIdAndTxt( "runningPrctileMex:maxlhs",
                "Too many output arguments.");
    }
    
    if (!(mxIsSingle(prhs[1]) || mxIsDouble(prhs[1]))) {
        mexErrMsgIdAndTxt( "runningPrctileMex:wrongInputTypeArg2",
                "Second argument must be single or double.");        
    }
    if (!(mxIsSingle(prhs[2]) || mxIsDouble(prhs[2]))) {
        mexErrMsgIdAndTxt( "runningPrctileMex:wrongInputTypeArg2",
                "Third argument must be single or double.");  
    }
    
    // Get inputs:
    const size_t winLength = static_cast<const size_t> (mxGetScalar(prhs[1]));
    const size_t nth = static_cast<const size_t> (mxGetScalar(prhs[2]));
    const size_t dataArrayLength = mxGetNumberOfElements(prhs[0]);
    
    // Create output array:
    plhs[0] = mxDuplicateArray(prhs[0]);
    
    // Call function depending on data type:
    if (mxIsSingle(prhs[0])) {
        runningPrctile((float *)mxGetData(prhs[0]), 
                (float *)mxGetData(plhs[0]), dataArrayLength, 
                winLength, nth);
    }
    else if (mxIsDouble(prhs[0])){
        runningPrctile((double *)mxGetData(prhs[0]), 
                (double *)mxGetData(plhs[0]), dataArrayLength, 
                winLength, nth);        
    }
    else if (mxIsLogical(prhs[0])){
        runningPrctile((bool *)mxGetData(prhs[0]), 
                (bool *)mxGetData(plhs[0]), dataArrayLength, 
                winLength, nth);        
    }
    else {
        mexErrMsgIdAndTxt( "runningPrctileMex:unknownType",
                "The data type of the first input is not supported.");
    }
    return;
}