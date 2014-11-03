% MAINSEISMICDATADENOISING performs seismic data denoising using sparse
% dictionary learning
%
% Referred Paper:
% Rubinstein, R.; Zibulevsky, M.; Elad, M., "Double Sparsity: Learning
% Sparse Dictionaries for Sparse Signal Approximation," Signal Processing,
% IEEE Transactions on , vol.58, no.3, pp.1553,1564, March 2010
% doi: 10.1109/TSP.2009.2036477
% keywords: {image coding;image denoising;sparse matrices;3D image
% denoising;computed tomography;double sparsity;learning sparse
% dictionaries;signal representation;sparse coding;sparse signal
% approximation;Computed tomography;K-SVD;dictionary learning;signal
% denoising;sparse coding;sparse representation},
% URL:
% http://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5325694&isnumber=5410625
%
%
% This matlab source file is free for use in academic research.
% All rights reserved.
%
% Written by Lingchen Zhu (zhulingchen@gmail.com)
% Center for Signal and Information Processing, Center for Energy & Geo Processing
% Georgia Institute of Technology

close all;
clear;
clc;


%% Data source
addpath(genpath('./modelData'));
addpath(genpath('./src'));
if ~isunix
    rmpath(genpath('./src/CurveLab-2.1.3/fdct_usfft_cpp'));
    rmpath(genpath('./src/CurveLab-2.1.3/fdct_wrapping_cpp'));
    rmpath(genpath('./src/CurveLab-2.1.3/fdct3d'));
end

dataFile = './modelData/denoising/timodel_shot_data_II_shot001-320.mat';
[dataFileDir, dataFileName] = fileparts(dataFile);
load(dataFile); % shot data from Hess VTI synthetic datasets

% % try barbara
% load('./modelData/denoising/barbara.mat'); % dataTrue
% dataTrue = dataTrue(1:256, end-255:end);

nBoundary = 20;
% dataTrue = dataTrue(nBoundary+1:end-nBoundary,:)';
dataTrue = dataTrue(1:8*floor(size(dataTrue, 1)/8), 1:8*floor(size(dataTrue, 2)/8));
% dataTrue = dataTrue(1:8*floor(size(dataTrue, 1)/8), 1:128);
[nSamples, nRecs] = size(dataTrue);


%% Remove mean and normalization
minData = min(dataTrue, [], 1);
maxData = max(dataTrue, [], 1);
meanData = mean(dataTrue, 1);
% dataTrue = bsxfun(@times, bsxfun(@minus, dataTrue, minData), 1./abs(maxData - minData));
dataTrue = bsxfun(@times, bsxfun(@minus, dataTrue, meanData), 1./abs(maxData - minData));

% %% Normalize data to unit norm
% for ir = 1:nRecs
%     dataTrue(:, ir) = dataTrue(:, ir) / norm(dataTrue(:, ir), 2);
% end


%% Prepare noisy data
sigma = 0.1;
noise = sigma * randn(size(dataTrue));
noisyData = dataTrue + noise;
save(fullfile(dataFileDir, [dataFileName, '_noisyData.mat']), 'noisyData', '-v7.3');
trainData = noisyData;


%% Plot figures
hFigDataTrue = figure; imshow(dataTrue);
title('Original Seismic Data');

hFigNoisyData = figure; imshow(noisyData);
psnrNoisyData = 20*log10(sqrt(numel(noisyData)) / norm(dataTrue(:) - noisyData(:), 2));
title(sprintf('Noisy Seismic Data, PSNR = %.2fdB', psnrNoisyData));
saveas(hFigNoisyData, fullfile(dataFileDir, [dataFileName, '_noisyData']), 'fig');
fprintf('------------------------------------------------------------\n');
fprintf('Noisy Seismic Data, PSNR = %.2fdB\n', psnrNoisyData);


%% Reference: denoising using wavelet
nlevels_wavelet = [0, 0, 0];        % Decomposition level, all 0 means wavelet
pfilter_wavelet = '9/7';            % Pyramidal filter
dfilter_wavelet = 'pkva';           % Directional filter
[vecWaveletCoeff, str] = pdfb2vec(pdfbdec(noisyData, pfilter_wavelet, dfilter_wavelet, nlevels_wavelet));

% Thresholding
% noiseVar = pdfb_nest(size(dataTrue, 1), size(dataTrue, 2), pfilter_wavelet, dfilter_wavelet, nlevels_wavelet);
thres_wavelet = 3 * sigma;
vecWaveletCoeff = vecWaveletCoeff .* (abs(vecWaveletCoeff) > thres_wavelet);

% Reconstruction
cleanData_wavelet = pdfbrec(vec2pdfb(vecWaveletCoeff, str), pfilter_wavelet, dfilter_wavelet);
save(fullfile(dataFileDir, [dataFileName, '_cleanData_wavelet.mat']), 'cleanData_wavelet', '-v7.3');

% Plot figures and PSNR output
hFigCleanedDataWavelet = figure; imshow(cleanData_wavelet);
psnrCleanData_wavelet = 20*log10(sqrt(numel(cleanData_wavelet)) / norm(dataTrue(:) - cleanData_wavelet(:), 2));
title(sprintf('Denoised Seismic Data (Wavelet), PSNR = %.2fdB', psnrCleanData_wavelet));
saveas(hFigCleanedDataWavelet, fullfile(dataFileDir, [dataFileName, '_cleanData_wavelet']), 'fig');
fprintf('------------------------------------------------------------\n');
fprintf('Denoised Seismic Data (Wavelet), PSNR = %.2fdB\n', psnrCleanData_wavelet);


%% Reference: denoising using Contourlet
nlevels_contourlet = [0, 3, 4];     % Decomposition level, all 0 means wavelet
pfilter_contourlet = '9/7';         % Pyramidal filter
dfilter_contourlet = 'pkva';        % Directional filter
[vecContourletCoeff, str] = pdfb2vec(pdfbdec(noisyData, pfilter_contourlet, dfilter_contourlet, nlevels_contourlet));

% Set up thresholds for coarse scales
noiseVar = pdfb_nest(size(dataTrue, 1), size(dataTrue, 2), pfilter_contourlet, dfilter_contourlet, nlevels_contourlet);
thres_contourlet = 3 * sigma * sqrt(noiseVar.');

% Slightly different thresholds for the finest scale
finestScale = str(end, 1);
finestScaleSize = sum(prod(str(str(:, 1) == finestScale, 3:4), 2));
thres_contourlet(end-finestScaleSize+1:end) = (4/3) * thres_contourlet(end-finestScaleSize+1:end);

% Thresholding
vecContourletCoeff = vecContourletCoeff .* (abs(vecContourletCoeff) > thres_contourlet);

% Reconstruction
cleanData_contourlet = pdfbrec(vec2pdfb(vecContourletCoeff, str), pfilter_contourlet, dfilter_contourlet);
save(fullfile(dataFileDir, [dataFileName, '_cleanData_contourlet.mat']), 'cleanData_contourlet', '-v7.3');

% Plot figures and PSNR output
hFigCleanedDataContourlet = figure; imshow(cleanData_contourlet);
psnrCleanData_contourlet = 20*log10(sqrt(numel(cleanData_contourlet)) / norm(dataTrue(:) - cleanData_contourlet(:), 2));
title(sprintf('Denoised Seismic Data (Contourlet), PSNR = %.2fdB', psnrCleanData_contourlet));
saveas(hFigCleanedDataContourlet, fullfile(dataFileDir, [dataFileName, '_cleanData_contourlet']), 'fig');
fprintf('------------------------------------------------------------\n');
fprintf('Denoised Seismic Data (Contourlet), PSNR = %.2fdB\n', psnrCleanData_contourlet);


%% Reference: denoising using Curvelet
is_real = 1;
nbscales = 4;
nbangles_coarse = 8;

if ~isunix
    coeffCurvelet = fdct_wrapping(noisyData, is_real, 2, nbscales, nbangles_coarse);
else
    coeffCurvelet = fdct_wrapping(noisyData, is_real, nbscales, nbangles_coarse);
end

% Set up thresholds for all scales
F = ones(nSamples, nRecs);
X = fftshift(ifft2(F)) * sqrt(nSamples * nRecs);
if ~isunix
    coeffX = fdct_wrapping(X, 0, 2, nbscales, nbangles_coarse);
else
    coeffX = fdct_wrapping(X, 0, nbscales, nbangles_coarse);
end
thres_curvelet = cell(size(coeffX));
for s = 1:length(coeffX)
    thres_curvelet{s} = cell(size(coeffX{s}));
    for w = 1:length(coeffX{s})
        A = coeffX{s}{w};
        thres_curvelet{s}{w} = 3 * sigma * sqrt(sum(sum(A.*conj(A))) / numel(A));
        if s == length(coeffX)
            thres_curvelet{s}{w} = (4/3) * thres_curvelet{s}{w};
        end
    end
end

% Thresholding
for s = 1:length(coeffCurvelet)
    for w = 1:length(coeffCurvelet{s})
        coeffCurvelet{s}{w} = coeffCurvelet{s}{w} .* (abs(coeffCurvelet{s}{w}) > thres_curvelet{s}{w});
    end
end

% Reconstruction
if ~isunix
    cleanData_curvelet = real(ifdct_wrapping(coeffCurvelet, is_real));
else
    cleanData_curvelet = real(ifdct_wrapping(coeffCurvelet, is_real, nbscales, nbangles_coarse));
end
save(fullfile(dataFileDir, [dataFileName, '_cleanData_curvelet.mat']), 'cleanData_curvelet', '-v7.3');

% Plot figures and PSNR output
hFigCleanedDataCurvelet = figure; imshow(cleanData_curvelet);
psnrCleanData_curvelet = 20*log10(sqrt(numel(cleanData_curvelet)) / norm(dataTrue(:) - cleanData_curvelet(:), 2));
title(sprintf('Denoised Seismic Data (Curvelet), PSNR = %.2fdB', psnrCleanData_curvelet));
saveas(hFigCleanedDataCurvelet, fullfile(dataFileDir, [dataFileName, '_cleanData_curvelet']), 'fig');
fprintf('------------------------------------------------------------\n');
fprintf('Denoised Seismic Data (Curvelet), PSNR = %.2fdB\n', psnrCleanData_curvelet);


%% Parameters for dictionary learning using sparse K-SVD
gain = 1;                                   % noise gain (default value 1.15)
trainBlockSize = 16;                        % for each dimension
trainBlockNum = 6000;                       % number of training blocks in the training set
trainIter = 20;
sigSpThres = sigma * trainBlockSize * gain; % pre-defined l2-norm error for BPDN
atomSpThres = 200;                          % a self-determind value to control the sparsity of matrix A


%% Base dictionary setting
nlevels_wavelet = [0, 0];       % Decomposition level, all 0 means wavelet
pfilter_wavelet = '9/7' ;       % Pyramidal filter
dfilter_wavelet = 'pkva' ;      % Directional filter


%% Dictionary learning using sparse K-SVD
fprintf('------------------------------------------------------------\n');
fprintf('Dictionary Learning\n');

[vecTrainBlockCoeff, str] = pdfb2vec(pdfbdec(zeros(trainBlockSize, trainBlockSize), pfilter_wavelet, dfilter_wavelet, nlevels_wavelet));
initDict = speye(length(vecTrainBlockCoeff), length(vecTrainBlockCoeff));
baseSynOp = @(x) pdfb(x, str, pfilter_wavelet, dfilter_wavelet, nlevels_wavelet, trainBlockSize, trainBlockSize, 1);
baseAnaOp = @(x) pdfb(x, str, pfilter_wavelet, dfilter_wavelet, nlevels_wavelet, trainBlockSize, trainBlockSize, 2);
[learnedDict, Coeffs, err] = sparseKsvd(trainData, baseSynOp, baseAnaOp, ...
    initDict, trainIter, trainBlockSize, trainBlockNum, atomSpThres, sigSpThres, 'bpdn');


%% show trained dictionary
[PhiSyn, PhiAna] = operator2matrix(baseSynOp, baseAnaOp, trainBlockSize * trainBlockSize);
dictImg = showdict(PhiSyn * learnedDict, [1 1]*sqrt(size(PhiSyn * learnedDict, 1)), round(sqrt(size(PhiSyn * learnedDict, 2))), round(sqrt(size(PhiSyn * learnedDict, 2))), 'whitelines', 'highcontrast');
hFigLearnedDict = figure; imshow(imresize(dictImg, 2, 'nearest')); title(sprintf('Trained Dictionary (%d iterations)', trainIter));
saveas(hFigLearnedDict, fullfile(dataFileDir, [dataFileName, '_learnedDict']), 'fig');


%% Denoising
fprintf('------------------------------------------------------------\n');
fprintf('Denoising\n');

cleanData_sparseKsvd = zeros(size(dataTrue));
totalBlockNum = (nSamples - trainBlockSize + 1) * (nRecs - trainBlockSize + 1);
processedBlocks = 0;

for ibatch = 1:nRecs-trainBlockSize+1
    fprintf('Batch %d... ', ibatch);
    % the current batch of blocks
    blocks = im2colstep(noisyData(:, ibatch:ibatch+trainBlockSize-1), trainBlockSize * [1, 1], [1, 1]);
    
    % % remove DC (mean values)
    % [blocks, dc] = remove_dc(blocks,'columns');
    
    cleanBlocks = zeros(size(blocks));
    blockCoeff = zeros(length(vecTrainBlockCoeff), nSamples - trainBlockSize + 1);
    for iblk = 1:nSamples - trainBlockSize + 1
        opts = spgSetParms('verbosity', 0, 'optTol', 1e-6);
        blockCoeff(:, iblk) = spg_bpdn(@(x, mode) learnedOp(x, baseSynOp, baseAnaOp, learnedDict, mode), blocks(:, iblk), sigSpThres, opts);
        % blockCoeff(:, iblk) = OMP({@(x) baseSynOp(learnedDict*x), @(x) learnedDict'*baseAnaOp(x)}, blocks(:, iblk), sigSpThres);
        cleanBlocks(:, iblk) = learnedOp(blockCoeff(:, iblk), baseSynOp, baseAnaOp, learnedDict, 1);
    end
    
    % % add DC (mean values)
    % cleanBlocks = add_dc(cleanBlocks, dc, 'columns');
    
    cleanBatch = col2imstep(cleanBlocks, [nSamples, trainBlockSize], trainBlockSize * [1, 1], [1, 1]);
    cleanData_sparseKsvd(:,ibatch:ibatch+trainBlockSize-1) = cleanData_sparseKsvd(:,ibatch:ibatch+trainBlockSize-1) + cleanBatch;
    
    processedBlocks = processedBlocks + (nSamples - trainBlockSize + 1);
    fprintf('Processed %d blocks\n', processedBlocks);
end

% average the denoised and noisy signals
cnt = countcover(size(noisyData), trainBlockSize * [1, 1], [1, 1]);
cleanData_sparseKsvd = cleanData_sparseKsvd./cnt;
save(fullfile(dataFileDir, [dataFileName, '_cleanData_sparseKsvd.mat']), 'cleanData_sparseKsvd', '-v7.3');


%% Plot figures and PSNR output
hFigCleanedDataSparseKsvd = figure; imshow(cleanData_sparseKsvd);
psnrCleanData_sparseKsvd = 20*log10(sqrt(numel(cleanData_sparseKsvd)) / norm(dataTrue(:) - cleanData_sparseKsvd(:), 2));
title(sprintf('Denoised Seismic Data, PSNR = %.2fdB', psnrCleanData_sparseKsvd));
saveas(hFigCleanedDataSparseKsvd, fullfile(dataFileDir, [dataFileName, '_cleanData_sparseKsvd']), 'fig');
fprintf('------------------------------------------------------------\n');
fprintf('Denoised Seismic Data, PSNR = %.2fdB\n', psnrCleanData_sparseKsvd);