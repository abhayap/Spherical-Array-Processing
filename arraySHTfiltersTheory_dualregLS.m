function [H_filt, h_filt, H_array] = arraySHTfiltersTheory_dualregLS(R, rho, mic_dirsAziElev, micR, micO, order_sht, Lfilt, fs, amp_threshold)
%ARRAYSHTFILTERSTHEORY_DUALREGLS Generate SHT filters based on theoretical responses
%(regularized least-squares)
%
%   Generate the filters to convert microphone signals from a spherical
%   microphone array to SH signals, based on an ideal theoretical model of 
%   the array. The filters are generated as a least-squares 
%   solution with a constraint on filter amplification, using Tikhonov 
%   regularization. The method formulates the LS problem in the spherical 
%   harmonic domain, by expressing the array response to an order-limited 
%   series of SH coefficients, similar to
%
%       Jin, C.T., Epain, N. and Parthy, A., 2014. 
%       Design, optimization and evaluation of a dual-radius spherical microphone array. 
%       IEEE/ACM Transactions on Audio, Speech, and Language Processing, 22(1), pp.193-204.
%
%   Inputs:
%       R:          radius of spherical array
%       mic_dirsAziElev:    nMics x 2 matrix of [azi elev] of the
%           microphones on the sphere, in rads
%       order_sht:  order of SH signals to generate
%       Lfilt:      number of FFT points for the output filters
%       fs:         sample rate for the output filters
%       amp_threshold:      max allowed amplification for filters, in dB
%
%   Outputs:
%       H_filt: nSH x nMics x (Lfilt/2+1) returned filters in the frequency 
%           domain (half spectrum up to Nyquist)
%       h_filt: Lfilt x nMics x nSH impulse responses of the above filters
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ARRAYSHTFILTERSTHEORY_DUALREGLS.M - 5/10/2016
% Archontis Politis, archontis.politis@aalto.fi
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

c = 343;
f = (0:Lfilt/2)'*fs/Lfilt;
k = 2*pi*f/c;
k_max = k(end);

Nmic = size(mic_dirsAziElev,1);
if order_sht>sqrt(Nmic)-1
    warning('Set order too high for the number of microphones, should be N<=sqrt(Q)-1')
    order_sht = floor( sqrt(Nmic)-1 );
end

mic_dirsAziIncl = [mic_dirsAziElev(:,1) pi/2-mic_dirsAziElev(:,2)];
order_array = floor(min(85,2*R*rho*k_max));
disp(order_array)
Y_array = sqrt(4*pi)*getSH(order_array, mic_dirsAziIncl, 'real');

% modal responses
bNrigid = sphModalCoeffsDual(order_array, k*R, k*R)/(4*pi); % due to modified SHs, the 4pi term disappears from the plane wave expansion
bNopen = sphModalCoeffsDual(order_array, k*R*rho, k*R)/(4*pi);

% array response in the SHD
H_array = zeros(Nmic, (order_array+1)^2, length(f));
for kk=1:length(f)
    temp_br = bNrigid(kk,:).';
    temp_bo = bNopen(kk,:).';
    temp_b = [repmat(temp_br,1,micR), repmat(temp_bo,1,micO)];
    B = replicatePerOrder(temp_b).';
    H_array(:,:,kk) = Y_array .* B;
end

a_dB = amp_threshold;
alpha = 10^(a_dB/20);
beta = 1/(2*alpha);
H_filt = zeros((order_sht+1)^2, Nmic, length(f));
for kk=1:length(f)
    tempH_N = H_array(:,:,kk);
    tempH_N_trunc = tempH_N(:,1:(order_sht+1)^2);
    H_filt(:,:,kk) = tempH_N_trunc' * inv(tempH_N*tempH_N' + beta^2*eye(Nmic));
end

if nargout>1
    % time domain filters
    h_filt = H_filt;
    h_filt(:,:,end) = abs(h_filt(:,:,end));
    h_filt = cat(3, h_filt, conj(h_filt(:,:,end-1:-1:2)));
    h_filt = real(ifft(h_filt, [], 3));
    h_filt = fftshift(h_filt, 3);
end
