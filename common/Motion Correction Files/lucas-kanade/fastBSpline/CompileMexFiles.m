function [] = CompileMexFiles()
    %Compiles mex files that accelerate B-spline evaluation
    mex evalBin.cpp
    mex evalBSpline.cpp
    mex evalBinTimesY.cpp
end